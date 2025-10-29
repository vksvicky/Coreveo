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
            // Just update the app appearance, don't access individual windows
            NSApp.appearance = getAppearance()
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
        
        // Notify that theme has changed
        NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
    }
    
    /// Get the appropriate NSAppearance for the current theme
    func getAppearance() -> NSAppearance? {
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

// Removed ThemedViewModifier to avoid memory management issues
// Views should handle their own theming through direct ThemeManager.shared access
