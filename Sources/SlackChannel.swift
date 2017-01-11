//
//  SlackChannel.swift
//  SlackBot
//
//  Created by Goran Blažič on 10/01/2017.
//
//

import Foundation
import Polymorphic

public class SlackChannel {
	private(set) public var id: String
	private(set) public var name: String
	private(set) public var isBotMember: Bool

	init(id: String, name: String, isBotMember: Bool = false) {
		self.id = id
		self.name = name
		self.isBotMember = isBotMember
	}

	init?(from: [String: Polymorphic?]?) {
		guard let from = from, let id = from["id"]??.string, let name = from["name"]??.string, let isBotMember = from["is_member"]??.bool else {
			return nil
		}
		self.id = id
		self.name = name
		self.isBotMember = isBotMember
	}

}
