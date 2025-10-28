import SwiftUI
import AppKit

/// About window for the application
struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon and title
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(spacing: 4) {
                    Text("Coreveo")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 2025.10.1")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            Text("A comprehensive system monitoring tool for macOS")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Features grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                FeatureCard(icon: "cpu", title: "CPU Monitor", description: "Real-time processor usage")
                FeatureCard(icon: "memorychip", title: "Memory Track", description: "RAM usage analysis")
                FeatureCard(icon: "externaldrive", title: "Disk Stats", description: "Storage performance")
                FeatureCard(icon: "network", title: "Network I/O", description: "Bandwidth monitoring")
            }
            
            // Keyboard shortcuts
            VStack(alignment: .leading, spacing: 12) {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRow(keys: ["⌘", ","], description: "Open Settings")
                    ShortcutRow(keys: ["⌘", "?"], description: "Show Help")
                    ShortcutRow(keys: ["⌘", "Q"], description: "Quit Coreveo")
                    ShortcutRow(keys: ["⌘", "M"], description: "Minimize Window")
                    ShortcutRow(keys: ["⌘", "W"], description: "Close Window")
                }
            }
            
            // Copyright and links
            VStack(spacing: 8) {
                Text("© 2025 Coreveo. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Link("Website", destination: URL(string: "https://github.com/vksvicky/Coreveo")!)
                    Link("Support", destination: URL(string: "https://github.com/vksvicky/Coreveo/issues")!)
                    Link("Privacy", destination: URL(string: "https://github.com/vksvicky/Coreveo")!)
                }
                .font(.caption)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Check for Updates") {
                    // TODO: Implement update checking
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("OK") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 500, height: 600)
        .themed()
    }
}

/// Feature card component
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

/// Keyboard shortcut row
struct ShortcutRow: View {
    let keys: [String]
    let description: String
    
    var body: some View {
        HStack {
            Text(description)
                .font(.caption)
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                }
            }
        }
    }
}

/// Window manager for About window
class AboutWindowManager: ObservableObject {
    private var aboutWindow: NSWindow?
    
    @MainActor
    func showAboutWindow() {
        if aboutWindow == nil {
            let contentView = AboutWindow()
                .environmentObject(ThemeManager.shared)
            
            aboutWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            aboutWindow?.title = "About Coreveo"
            aboutWindow?.contentView = NSHostingView(rootView: contentView)
            aboutWindow?.center()
            aboutWindow?.isReleasedWhenClosed = false
        }
        
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#Preview {
    AboutWindow()
        .environmentObject(ThemeManager())
}
