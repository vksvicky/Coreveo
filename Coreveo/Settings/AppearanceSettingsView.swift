import SwiftUI

/// Appearance settings tab
struct AppearanceSettingsView: View {
    @State private var selectedTheme = AppTheme.system
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.system(size: 34, weight: .bold))
                    
                    Text("Customize the look and feel of Coreveo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Theme")
                        .font(.system(size: 17, weight: .semibold))
                    
                    VStack(spacing: 14) {
                        ForEach(AppTheme.allCases) { theme in
                            ThemeOptionView(
                                theme: theme,
                                isSelected: selectedTheme == theme
                            ) {
                                selectedTheme = theme
                                ThemeManager.shared.currentTheme = theme
                            }
                        }
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedTheme = ThemeManager.shared.currentTheme
        }
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
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
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
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func themeDescription(_ theme: AppTheme) -> String {
        switch theme {
        case .system:
            return "Follows your system appearance"
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        }
    }
}

