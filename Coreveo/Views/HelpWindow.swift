import AppKit
import Foundation
import SwiftUI

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
        MarkdownViewer(markdown: markdownText)
            .padding(.vertical, 8)
    }
}