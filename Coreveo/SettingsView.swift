import SwiftUI

/// Main settings view for the application
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(selection: $selectedTab) {
                SettingsSection(
                    icon: "paintbrush",
                    title: "Appearance",
                    subtitle: "Theme and visual settings"
                ) {
                    selectedTab = 0
                }
                .tag(0)
                
                SettingsSection(
                    icon: "gear",
                    title: "General",
                    subtitle: "General app preferences"
                ) {
                    selectedTab = 1
                }
                .tag(1)
                
                SettingsSection(
                    icon: "info.circle",
                    title: "About",
                    subtitle: "App information and support"
                ) {
                    selectedTab = 2
                }
                .tag(2)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200, maxWidth: 250)
            
            // Main content
            Group {
                switch selectedTab {
                case 0:
                    AppearanceSettingsView()
                case 1:
                    GeneralSettingsView()
                case 2:
                    AboutSettingsView()
                default:
                    AppearanceSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Settings")
        .frame(minWidth: 600, minHeight: 400)
        .themed()
    }
}

/// Individual settings section in sidebar
struct SettingsSection: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Appearance settings tab
struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Appearance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Customize the look and feel of Coreveo")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Theme")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeOptionView(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            themeManager.currentTheme = theme
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Preview")
                    .font(.headline)
                
                ThemePreviewView()
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Individual theme option
struct ThemeOptionView: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: theme.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(themeDescription(theme))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func themeDescription(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return "Follows your system appearance"
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        }
    }
}

/// Theme preview component
struct ThemePreviewView: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Sample Window Title")
                    .font(.headline)
                
                Text("This is how your interface will look with the selected theme.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Sample Button") { }
                        .buttonStyle(.borderedProminent)
                    
                    Button("Cancel") { }
                        .buttonStyle(.bordered)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
    }
}

/// General settings tab
struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("General")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("General application preferences")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Coming Soon")
                    .font(.headline)
                
                Text("Additional settings will be added here in future updates.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// About settings tab
struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("About")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Coreveo system monitoring application")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Coreveo")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 2025.10.1")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("System Performance Monitor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        FeatureRow(icon: "cpu", text: "Real-time CPU monitoring")
                        FeatureRow(icon: "memorychip", text: "Memory usage tracking")
                        FeatureRow(icon: "externaldrive", text: "Disk performance analysis")
                        FeatureRow(icon: "network", text: "Network activity monitoring")
                        FeatureRow(icon: "battery.100", text: "Battery health insights")
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Requirements")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• macOS 14.0 or later")
                        Text("• Apple Silicon or Intel processor")
                        Text("• 50 MB available storage")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Feature row component
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}
