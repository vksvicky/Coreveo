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
    func testGivenHelpMarkdown_WhenRendered_ThenViewerUsesRenderer() {
        // Given
        let mock = MockRenderer()
        let md = "## Coreveo Help\n\n- Item 1\n- Item 2"
        let viewer = MarkdownViewer(markdown: md, renderer: mock)
        
        // When: Create NSView and trigger update
        let scroll = viewer.makeNSView(context: .init())
        viewer.updateNSView(scroll, context: .init())
        
        // Then
        XCTAssertEqual(mock.lastInput, md)
        let textView = scroll.documentView as? NSTextView
        XCTAssertEqual(textView?.string.hasPrefix("[MOCK]"), true)
    }
}
