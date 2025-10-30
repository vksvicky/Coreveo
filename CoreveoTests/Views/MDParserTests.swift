@testable import Coreveo
import XCTest

final class MDParserTests: XCTestCase {
    private let parser = MDParser()

    func testParsesHeadingsParagraphsAndLists() {
        let md = """
        # Title

        Intro paragraph spanning
        multiple lines.

        - First
        - Second
        1. One
        2. Two
        """
        let nodes = parser.parse(md)
        XCTAssertEqual(nodes.count, 4)
        XCTAssertEqual(nodes[0], .heading(level: 1, text: "Title"))
        if case let .paragraph(text) = nodes[1] {
            XCTAssertTrue(text.contains("Intro paragraph"))
            XCTAssertTrue(text.contains("multiple lines"))
        } else { XCTFail("Expected paragraph") }
        XCTAssertEqual(nodes[2], .unorderedList(items: ["First", "Second"]))
        XCTAssertEqual(nodes[3], .orderedList(items: ["One", "Two"]))
    }

    func testParsesCodeBlockWithLanguage() {
        let md = """
        ```swift
        let x = 1
        print(x)
        ```
        """
        let nodes = parser.parse(md)
        XCTAssertEqual(nodes.count, 1)
        if case let .codeBlock(lang, code) = nodes[0] {
            XCTAssertEqual(lang, "swift")
            XCTAssertTrue(code.contains("let x = 1"))
            XCTAssertTrue(code.contains("print(x)"))
        } else { XCTFail("Expected code block") }
    }

    func testEmptyLinesFlushParagraphAndLists() {
        let md = """
        First line

        - A

        Second para
        """
        let nodes = parser.parse(md)
        XCTAssertEqual(nodes.count, 3)
        XCTAssertEqual(nodes[0], .paragraph(text: "First line"))
        XCTAssertEqual(nodes[1], .unorderedList(items: ["A"]))
        XCTAssertEqual(nodes[2], .paragraph(text: "Second para"))
    }
}


