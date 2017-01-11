//
//  SlackMessage.swift
//  SlackBot
//
//  Created by Goran Blažič on 11/01/2017.
//  Copyright © 2017 goranche.net. All rights reserved.
//

import Foundation

public class SlackMessage: SlackEvent {

	public let channelId: String
	public let userId: String
	public let timeStamp: Double
	public let text: String

	public var user: SlackUser? {
		guard !userId.isEmpty else {
			return nil
		}
		return slackBot.users.filter { $0.id == userId }.first
	}

	public var channel: SlackChannel? {
		guard !channelId.isEmpty else {
			return nil
		}
		return slackBot.channels.filter { $0.id == channelId }.first
	}

	public var amMentioned: Bool {
		// This might trigger a false positive if someone writes "<@*>" to a channel...
		return text.contains("<@\(slackBot.botId ?? "*")>")
	}

	override public init(from json: [String: Any], slackBot: SlackBot) {
		channelId = json["channel"] as? String ?? ""
		userId = json["user"] as? String ?? ""
		timeStamp = Double(json["ts"] as? String ?? "") ?? 0
		text = json["text"] as? String ?? ""
		super.init(from: json, slackBot: slackBot)
	}

	public func reply(with text: String) {
		_ = slackBot.send(toChannelId: channelId, message: text)
	}

}
