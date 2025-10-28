import SwiftUI
import AppKit

/// Theme options for the application
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

/// Manages app theme and appearance settings
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "AppTheme")
            applyTheme()
        }
    }
    
    @Published var colorScheme: ColorScheme? {
        didSet {
            // Update all windows when color scheme changes
            NSApp.windows.forEach { window in
                window.appearance = getAppearance()
            }
        }
    }
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Load saved theme or default to system
        let savedTheme = userDefaults.string(forKey: "AppTheme") ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .system
        applyTheme()
    }
    
    /// Apply the current theme to the app
    private func applyTheme() {
        switch currentTheme {
        case .system:
            colorScheme = nil // Let system decide
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        }
        
        // Update app appearance
        NSApp.appearance = getAppearance()
    }
    
    /// Get the appropriate NSAppearance for the current theme
    private func getAppearance() -> NSAppearance? {
        switch currentTheme {
        case .system:
            return nil // Use system default
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
    
    /// Get the current effective color scheme
    var effectiveColorScheme: ColorScheme? {
        if currentTheme == .system {
            return NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light
        }
        return colorScheme
    }
}

/// Custom colors that adapt to the current theme
struct ThemeColors {
    static let primary = Color("PrimaryColor")
    static let secondary = Color("SecondaryColor")
    static let accent = Color("AccentColor")
    static let background = Color("BackgroundColor")
    static let surface = Color("SurfaceColor")
    static let text = Color("TextColor")
    static let textSecondary = Color("TextSecondaryColor")
    static let border = Color("BorderColor")
    static let success = Color("SuccessColor")
    static let warning = Color("WarningColor")
    static let error = Color("ErrorColor")
}

/// View modifier to apply theme-aware colors
struct ThemedViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Use the singleton to avoid crashes when EnvironmentObject isn't injected
        content
            .preferredColorScheme(ThemeManager.shared.colorScheme)
    }
}

extension View {
    /// Apply theme-aware styling to any view
    func themed() -> some View {
        modifier(ThemedViewModifier())
    }
}
