//
//  SlackBot.swift
//  clockyBot
//
//  Created by Goran Blažič on 09/01/2017.
//  Copyright © 2017 goranche.net. All rights reserved.
//

import Foundation
import Console
import Vapor
import Transport
import HTTP
import TLS

fileprivate let slackRtmUrl = "https://slack.com/api/rtm.start"

public class SlackBot {

	public let slackBotVersion = "0.1"

	public enum SlackBotError: Error {
		// TODO: Add error cases as needed
		case unknown
		case invalidRtmResponse
		case connectionDropped
		case connectionRefused(String)
		case invalidMessage
	}

	public enum State {
		case initialized
		case connecting
		case verifyingConnection
		case connectError(Error)
		case connected
		case disconnecting
		case disconnected
		case error(Error)
	}

	private let botToken: String
	public var autoReconnect: Bool
	private var disconnectRequested: Bool = false

	private(set) public var log: LogProtocol

	public let environment: Environment

	// Leaving this for debugging purposes, when functionality complete (-ish), may be removed
	private(set) public var rtmResponse: HTTP.Response? = nil

	private(set) public var wssURL: String? = nil

	private(set) public var botId: String? = nil
	private(set) public var botName: String? = nil
	private(set) public var teamId: String? = nil
	private(set) public var teamName: String? = nil

	private(set) public var channels: [SlackChannel] = []
	private(set) public var groups: [SlackGroup] = []
	private(set) public var users: [SlackUser] = []

	public var onReceivedEvent: ((SlackBot, String) -> Void)? = nil

	public var onStateChange: ((SlackBot) -> Void)? = nil
	private(set) public var state: State = .initialized {
		didSet {
			log.verbose("state changed to \(state)")
			onStateChange?(self)
		}
	}

	public var onMessage: ((SlackBot, SlackMessage) -> Void)? = nil

	private var webSocket: WebSocket? = nil

	// MARK: - Lifecycle stuff

	public init(withToken botToken: String, arguments: [String]? = nil, environment environmentProvided: Environment? = nil, log logProvided: LogProtocol? = nil, autoReconnect: Bool = true) {
		self.botToken = botToken
		self.autoReconnect = autoReconnect

		let arguments = arguments ?? CommandLine.arguments

		let terminal = Terminal(arguments: arguments)
		if let provided = logProvided  {
			self.log = provided
		} else {
			self.log = ConsoleLogger(console: terminal)
		}

		let environment: Environment
		if let provided = environmentProvided {
			environment = provided
		} else {
			// If this fails build, go to the Environment enum file, and change line 45 to public
			// Waiting for https://github.com/vapor/vapor/pull/786 to be approved 🙏
			environment = CommandLine.environment ?? .development
		}
		self.environment = environment

		switch environment {
		case .development:
			self.log.enabled = LogLevel.all
		case .test:
			self.log.enabled = [.fatal, .error, .warning, .info]
		case .custom:
			self.log.enabled = [.fatal, .error, .warning, .info, .verbose]
		default:
			self.log.enabled = [.fatal, .error, .warning]
		}

		defaultClientConfig = {
			return try TLS.Config(context: try Context(mode: .client), certificates: .none, verifyHost: false, verifyCertificates: false, cipher: .compat)
		}

		log.info("SlackBot \(slackBotVersion) initialized")
		log.verbose("environment: \(environment)")
		log.verbose("botToken: \(botToken)")
	}

	// MARK: - Public methods

	public func connect(completion: @escaping (SlackBot, Error?) -> Void) {
		state = .connecting

		disconnectRequested = false

		let headers: [HeaderKey: String] = ["Accept": "application/json; charset=utf-8"]
		let query: [String: CustomStringConvertible] = ["token": botToken, "simple_latest": 1, "no_unreads": 1]

		do {
			rtmResponse = try BasicClient.get(slackRtmUrl, headers: headers, query: query)
			guard let rtmResponse = rtmResponse else {
				log.error("got nil value for rtmResponse")
				throw SlackBotError.invalidRtmResponse
			}

			guard rtmResponse.data["ok"]?.bool ?? false else {
				log.error("rtmResponse didn't contain an ok")
				throw SlackBotError.invalidRtmResponse
			}

			wssURL = rtmResponse.data["url"]?.string
			guard let wssURL = wssURL else {
				log.error("rtmResponse didn't contain a url")
				throw SlackBotError.invalidRtmResponse
			}

			botId = rtmResponse.data["self", "id"]?.string
			botName = rtmResponse.data["self", "name"]?.string
			teamId = rtmResponse.data["team", "id"]?.string
			teamName = rtmResponse.data["team", "name"]?.string
			guard let _ = botId, let _ = botName, let _ = teamId, let _ = teamName else {
				log.error("rtmResponse didn't contain bot/team id/name")
				throw SlackBotError.invalidRtmResponse
			}

			channels = rtmResponse.data["channels"]?.array?.flatMap({ SlackChannel(from: $0.object) }) ?? []
			groups = rtmResponse.data["groups"]?.array?.flatMap({ SlackGroup(from: $0.object) }) ?? []
			users = rtmResponse.data["users"]?.array?.flatMap({ SlackUser(from: $0.object) }) ?? []

			state = .verifyingConnection
			try WebSocket.connect(to: wssURL) { webSocket in
				self.webSocket = webSocket
				webSocket.onText = { webSocket, text in
					self.log.debug("websocket received during verify: \(text)")

					let message = SlackEvent.construct(from: text, slackBot: self)

					guard message.type == .hello else {
						self.log.error("didn't receive a hello from Slack")

						try? webSocket.close()
						self.webSocket = nil

						var error: SlackBotError = .connectionDropped
						if let errorString = text.object?["error"]?.object?["msg"]?.string {
							error = .connectionRefused(errorString)
						}
						self.state = .connectError(error)
						completion(self, error)

						self.state = .initialized
						return
					}

					webSocket.onText = self.handleText
					webSocket.onClose = self.handleClose
					self.state = .connected
					completion(self, nil)
				}
				webSocket.onClose = { _ in
					self.log.debug("websocket closed during verify")
					self.state = .connectError(SlackBotError.connectionDropped)
				}

			}
		} catch let error {
			state = .connectError(error)
			log.error("error occurred while retrieving initial RTM data\n\(error.localizedDescription)")
			completion(self, error)
			state = .initialized
		}
	}

	public func disconnect(completion: () -> Void) {
		disconnectRequested = true
		try? webSocket?.close()
	}

	public func send(toChannel: SlackChannel, message text: String) -> Bool {
		return send(toChannelId: toChannel.id, message: text)
	}

	public func send(toChannelId: String, message text: String) -> Bool {
		do {
			let message: [String: Any] = [
				"id": makeRandomId(),
				"channel": toChannelId,
				"type": "message",
				"text": text
			]
			try webSocket?.send(String(data: try JSONSerialization.data(withJSONObject: message, options: []), encoding: .utf8) ?? "")
			return true
		} catch {
			return false
		}
	}

	// MARK: - Helper methods

	private func makeRandomId() -> UInt32 {
#if os(Linux)
		return UInt32(libc.random() % Int(UInt32.max))
#else
		return UInt32(arc4random_uniform(UInt32.max))
#endif
	}

	private func handleText(webSocket: WebSocket, text: String) {
		log.debug("handleText: \(text)")
		onReceivedEvent?(self, text)
		let slackEvent = SlackEvent.construct(from: text, slackBot: self)
		switch slackEvent.type {
		case .message:
			if let slackMessage = slackEvent as? SlackMessage {
				onMessage?(self, slackMessage)
			}
		default:
			log.info("unsupported event type: \(slackEvent.type)")
		}

		if text.contains("dropTest") {
			try? webSocket.close()
		}
	}

	private func handleClose(webSocket: WebSocket, code: UInt16?, reason: String?, clean: Bool) {
		log.debug("handleClose")
		self.webSocket = nil
		self.state = .initialized

		if autoReconnect && !disconnectRequested {
			log.info("reconnecting")
			connect(completion: { _ in })
		}
	}

}
