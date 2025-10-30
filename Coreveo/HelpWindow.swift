import AppKit
import SwiftUI
import Foundation

final class HelpWindowManager {
    private static var helpWindow: NSWindow?
    
    @MainActor
    static func showHelpWindow() {
        if let existing = helpWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Coreveo Help"
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = NSApp.appearance
        window.contentView = NSHostingView(rootView: MarkdownHelpView())
        helpWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

private struct MarkdownHelpView: View {
    private func loadHelpMarkdown() -> String? {
        if let url = Bundle.main.url(forResource: "HELP", withExtension: "md"),
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        for sub in ["docs", "Doc", "Documentation", "Resources"] {
            if let url = Bundle.main.url(forResource: "HELP", withExtension: "md", subdirectory: sub),
               let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        if let urls = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: nil) {
            if let match = urls.first(where: { $0.lastPathComponent == "HELP.md" }),
               let data = try? Data(contentsOf: match),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
    
    private var markdownText: String {
        if let text = loadHelpMarkdown() { return text }
        return "# Coreveo Help\n\nHELP.md not bundled."
    }
    
    var body: some View {
        MarkdownTextView(markdown: markdownText)
            .padding(.vertical, 8)
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    let markdown: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesFontPanel = false
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
        if let attr = try? NSAttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .full),
            baseURL: Bundle.main.bundleURL
        ) {
            textView.textStorage?.setAttributedString(attr)
            return
        }
        // Fallback to plain text
        textView.string = markdown
    }
}