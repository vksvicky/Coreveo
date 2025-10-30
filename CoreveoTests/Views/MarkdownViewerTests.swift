@testable import Coreveo
import XCTest

final class MarkdownViewerTests: XCTestCase {
    func testNativeRendererParsesHeading() {
        // Given
        let renderer = NativeMarkdownRenderer()
        let md = "# Title\n\nSome text."
        
        // When
        let attr = renderer.render(markdown: md, baseURL: nil)
        
        // Then: contains attributed string with content (basic sanity)
        XCTAssertTrue(attr.string.contains("Title"))
        XCTAssertTrue(attr.string.contains("Some text."))
    }
    
    func testRendererFallbackToPlainTextOnInvalidMarkdown() {
        // Given
        let renderer = NativeMarkdownRenderer()
        let md = String(repeating: "\0", count: 4) // invalid content
        
        // When
        let attr = renderer.render(markdown: md, baseURL: nil)
        
        // Then
        XCTAssertEqual(attr.string.count, md.count)
    }
}
