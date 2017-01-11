//
//  SlackEvent.swift
//  SlackBot
//
//  Created by Goran Blažič on 10/01/2017.
//  Copyright © 2017 goranche.net. All rights reserved.
//

import Foundation

public class SlackEvent {

	public enum EventType {
		case unknown
		case invalid
		case unsupported
		case hello
		case message
		case error

		public init(_ string: String) {
			switch string {
			case "hello":
				self = .hello
			case "message":
				self = .message
			case "error":
				self = .error
			default:
				self = .unknown
			}
		}
	}

	let type: EventType
	let errorCode: Int?
	let errorMessage: String?

	public let slackBot: SlackBot

	public init(type: EventType = .unknown, errorCode: Int? = nil, errorMessage: String? = nil, slackBot: SlackBot) {
		self.type = type
		self.errorCode = errorCode
		self.errorMessage = errorMessage
		self.slackBot = slackBot
	}

	public init(from json: [String: Any], slackBot: SlackBot) {
		self.slackBot = slackBot
		type = EventType(json["type"] as? String ?? "")
		guard let error = json["error"] as? [String: Any] else {
			errorCode = nil
			errorMessage = nil
			return
		}
		errorCode = error["code"] as? Int
		errorMessage = error["msg"] as? String
	}

	public class func construct(from message: String, slackBot: SlackBot) -> SlackEvent {
		guard let data = message.data(using: .utf8), let temp = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any], let json = temp, let type = json["type"] as? String else {
			return SlackEvent(type: .invalid, slackBot: slackBot)
		}
		switch EventType(type) {
		case .message:
			return SlackMessage(from: json, slackBot: slackBot)
		default:
			return SlackEvent(from: json, slackBot: slackBot)
		}
	}

}
