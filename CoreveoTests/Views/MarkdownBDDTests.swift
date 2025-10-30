@testable import Coreveo
import XCTest

private final class MockRenderer: MarkdownRendering {
    var lastInput: String = ""
    func render(markdown: String, baseURL: URL?) -> NSAttributedString {
        lastInput = markdown
        return NSAttributedString(string: "[MOCK]\n" + markdown)
    }
}

final class MarkdownBDDTests: XCTestCase {
    func testGivenHelpMarkdown_WhenRendered_ThenMockRendererReceivesInput() {
        // Given
        let mock = MockRenderer()
        let md = "## Coreveo Help\n\n- Item 1\n- Item 2"
        
        // When: Use renderer directly (viewer injects this in production)
        let rendered = mock.render(markdown: md, baseURL: nil)
        
        // Then
        XCTAssertEqual(mock.lastInput, md)
        XCTAssertTrue(rendered.string.hasPrefix("[MOCK]"))
    }
}
