import AppKit
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
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Coreveo Help"
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = ThemeManager.shared.getAppearance()
        window.contentView = NSHostingView(rootView: HelpView())
        helpWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Coreveo Help")
                    .font(.system(size: 28, weight: .bold))
                Group {
                    Text("Permissions Overview").font(.headline)
                    Text("Coreveo needs limited permissions. Accessibility enables limited UI interactions; Full Disk Access improves certain readings; Network permission is not required unless a Network Extension is present.")
                }
                Group {
                    Text("Accessibility").font(.headline)
                    Text("Grant via System Settings → Privacy & Security → Accessibility. Use the in‑app Open System Settings button from the Permissions tab.")
                }
                Group {
                    Text("Full Disk Access").font(.headline)
                    Text("Optional. Grant via System Settings → Privacy & Security → Full Disk Access. Use the in‑app button to jump there.")
                }
                Group {
                    Text("Network").font(.headline)
                    Text("Not required. Coreveo does not include a Network Extension. If one is present on your Mac, the app may show an informational row; otherwise it’s hidden or marked Not required.")
                }
                Group {
                    Text("General Settings").font(.headline)
                    Text("Launch at Login, Start Monitoring on Launch, Show Menu Bar Item, Refresh Interval (0.5s–5s), Temperature Units (Celsius/Fahrenheit).")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}