import XCTest
@testable import ReadThisTextToMe

final class TextProcessingServiceTests: XCTestCase {
    let service = TextProcessingService()

    func testTrimsWhitespace() {
        let result = service.clean("  hello world  ")
        XCTAssertEqual(result, "hello world")
    }

    func testCollapsesMultipleNewlines() {
        let result = service.clean("hello\n\n\n\n\nworld")
        XCTAssertEqual(result, "hello\n\nworld")
    }

    func testCollapsesMultipleSpaces() {
        let result = service.clean("hello    world")
        XCTAssertEqual(result, "hello world")
    }

    func testEmptyString() {
        let result = service.clean("")
        XCTAssertEqual(result, "")
    }

    func testPreservesSingleNewlines() {
        let result = service.clean("line one\nline two")
        XCTAssertEqual(result, "line one\nline two")
    }
}
