import AppKit
import SwiftUI

/// Abstraction over markdown rendering so we can swap implementations or mock in tests.
protocol MarkdownRendering {
    func render(markdown: String, baseURL: URL?) -> NSAttributedString
}

/// Native renderer using Apple's markdown parser.
struct NativeMarkdownRenderer: MarkdownRendering {
    func render(markdown: String, baseURL: URL?) -> NSAttributedString {
        if let rich = try? NSAttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .full),
            baseURL: baseURL
        ) {
            return rich
        }
        return NSAttributedString(string: markdown)
    }
}

/// SwiftUI Markdown viewer that renders attributed text using an injected renderer.
struct MarkdownViewer: NSViewRepresentable {
    let markdown: String
    let renderer: MarkdownRendering
    
    init(markdown: String, renderer: MarkdownRendering = NativeMarkdownRenderer()) {
        self.markdown = markdown
        self.renderer = renderer
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesFindBar = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.linkTextAttributes = [ .foregroundColor: NSColor.linkColor ]
        
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = false
        scroll.documentView = textView
        
        update(textView: textView)
        return scroll
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            update(textView: textView)
        }
    }
    
    private func update(textView: NSTextView) {
        let attributed = renderer.render(markdown: markdown, baseURL: Bundle.main.bundleURL)
        textView.textStorage?.setAttributedString(attributed)
    }
}
