//
//  SlackUser.swift
//  SlackBot
//
//  Created by Goran Blažič on 10/01/2017.
//
//

import Foundation
import Polymorphic

public class SlackUser {
	private(set) public var id: String
	private(set) public var name: String
	private(set) public var realName: String

	init(id: String, name: String, realName: String? = nil) {
		self.id = id
		self.name = name
		self.realName = realName ?? name
	}

	init?(from: [String: Polymorphic?]?) {
		guard let from = from, let id = from["id"]??.string, let name = from["name"]??.string, let realName = from["name"]??.string else {
			return nil
		}
		self.id = id
		self.name = name
		self.realName = realName
	}
}
