//
//  SlackGroup.swift
//  SlackBot
//
//  Created by Goran Blažič on 10/01/2017.
//
//

import Foundation
import Polymorphic

public class SlackGroup {
	private(set) var id: String
	private(set) var name: String

	init(id: String, name: String) {
		self.id = id
		self.name = name
	}

	init?(from: [String: Polymorphic?]?) {
		guard let from = from, let id = from["id"]??.string, let name = from["name"]??.string else {
			return nil
		}
		self.id = id
		self.name = name
	}
}
