import XCTest
@testable import SlackBot

class SlackBotTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(SlackBot().text, "Hello, World!")
    }


    static var allTests : [(String, (SlackBotTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
