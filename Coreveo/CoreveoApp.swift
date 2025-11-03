import AppKit
import SwiftUI
import ApplicationServices // For AXIsProcessTrustedWithOptions
import CoreGraphics // For CGWindowListCopyWindowInfo
import Darwin

@main
struct CoreveoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showOnboarding = true
    
    // Helper function to get the real user home directory
    static func getRealHomeDirectory() -> String? {
        // Try multiple methods to get the real home directory
        
        // Method 1: Environment variable (most reliable for sandboxed apps)
        if let homeFromEnv = ProcessInfo.processInfo.environment["HOME"] {
            NSLog("[App] Got home from environment: \(homeFromEnv)")
            return homeFromEnv
        }
        
        // Method 2: getpwuid (fallback)
        let uid = getuid()
        if let pw = getpwuid(uid),
           let homeDir = pw.pointee.pw_dir {
            let homeFromPwuid = String(cString: homeDir)
            NSLog("[App] Got home from getpwuid: \(homeFromPwuid)")
            return homeFromPwuid
        }
        
        NSLog("[App] ⚠️ Could not determine real home directory")
        return nil
    }
    
    var body: some Scene {
        WindowGroup {
                ContentView()
                    .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Coreveo") {
                    NSApp.orderFrontStandardAboutPanel(options: [:])
                }
                .keyboardShortcut("?", modifiers: [])
            }
            
            // Remove default "New Window" from the File menu
            CommandGroup(replacing: .newItem) { }

            // Remove Edit menu items we don't use
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .textEditing) { }

            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    appDelegate.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button("Coreveo Help") {
                    HelpWindowManager.showHelpWindow()
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])
            }
        }
    }
    
    private func checkIfOnboardingNeeded() {
        NSLog("[App] checkIfOnboardingNeeded called")
        
        // Check if user has completed onboarding before
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        NSLog("[App] hasCompletedOnboarding: \(hasCompletedOnboarding)")
        
        // For testing: Hold Shift key to reset onboarding
        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
        NSLog("[App] isShiftPressed: \(isShiftPressed)")
        if isShiftPressed {
            NSLog("[App] Shift pressed - resetting onboarding")
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            showOnboarding = true
            return
        }
        
        // Always check permissions first - if granted, skip onboarding regardless of stored flag
        let permissionsGranted = arePermissionsAlreadyGranted()
        
        if permissionsGranted {
            NSLog("[App] All required permissions granted - skipping onboarding and showing main app")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            showOnboarding = false
        } else {
            NSLog("[App] Permissions missing - showing onboarding")
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                showOnboarding = true
        }
    }
    
    private func arePermissionsAlreadyGranted() -> Bool {
        NSLog("[App] Checking permissions...")
        
        // Use PermissionManager for consistent permission checking
        let status = PermissionManager.shared.getPermissionStatus()
        
        NSLog("[App] Permission check - Accessibility: \(status.hasAccessibility), Full Disk Access: \(status.hasFullDiskAccess)")
        
        // Only require Accessibility and Full Disk Access for basic functionality
        return status.hasAllRequiredPermissions
    }

    private func runPermissionDiagnostics() {
        NSLog("[Diag] ===== Permission Diagnostics =====")
        
        // Accessibility check
        let axTrusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary)
        NSLog("[Diag] Accessibility (AXIsProcessTrusted): \(axTrusted)")
        
        // Secondary AX signal via system-wide element
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemWideElement,
                                                          kAXFocusedApplicationAttribute as CFString,
                                                          &focusedApp)
        NSLog("[Diag] Accessibility (System-wide focused app query): \(focusedResult == .success)")
        
        // Full Disk Access check with detailed diagnostics
        NSLog("[Diag] === Full Disk Access Detailed Check ===")
        
        let fileManager = FileManager.default
        
        // Show what home directory we're using
        let sandboxHome = NSHomeDirectory()
        NSLog("[Diag] Sandbox home: \(sandboxHome)")
        
        let realHome = CoreveoApp.getRealHomeDirectory() ?? "unknown"
        NSLog("[Diag] Real home (via getpwuid): \(realHome)")
        
        // Test each protected path individually
        let testPaths = [
            "\(realHome)/Library/Mail",
            "\(realHome)/Library/Safari", 
            "\(realHome)/Library/Calendars"
        ]
        
        var anySuccess = false
        for path in testPaths {
            let exists = fileManager.fileExists(atPath: path)
            NSLog("[Diag] Path exists: \(exists) - \(path)")
            
            if exists {
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: path)
                    NSLog("[Diag] ✅ FDA SUCCESS: Read \(contents.count) items from \(path)")
                    anySuccess = true
                } catch let error as NSError {
                    NSLog("[Diag] ❌ FDA FAILED: \(path)")
                    NSLog("[Diag]    Error: \(error.domain) code:\(error.code) - \(error.localizedDescription)")
                }
            }
        }
        
        NSLog("[Diag] Full Disk Access Result: \(anySuccess ? "✅ GRANTED" : "❌ NOT GRANTED")")
        NSLog("[Diag] Summary → Accessibility: \(axTrusted), Full Disk Access: \(anySuccess)")
        
        // If missing permissions, surface onboarding
        if !(axTrusted && anySuccess) {
            NSLog("[Diag] Missing required permissions → presenting onboarding")
            showOnboarding = true
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        // Delegate to PermissionManager for consistent checking
        return PermissionManager.shared.checkAccessibilityPermission()
    }
    
    private func checkFullDiskAccessPermission() -> Bool {
        // Delegate to PermissionManager for consistent checking
        return PermissionManager.shared.checkFullDiskAccessPermission()
    }
    
}

// MARK: - Help View

/// App delegate for handling macOS-specific functionality
class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var themeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as regular app (not menu bar only)
        NSApp.setActivationPolicy(.regular)
        
        // Observe theme changes and update settings window appearance
        themeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ThemeDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateSettingsWindowAppearance()
            }
        }
    }
    
    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true // Quit app when all windows are closed
    }
    
    @MainActor private func updateSettingsWindowAppearance() {
        if let window = settingsWindow {
            window.appearance = ThemeManager.shared.getAppearance()
        }
    }
    
    @MainActor
    func showSettingsWindow() {
        // Reuse existing window if it exists
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Settings"
        // Set a fresh autosave name so old dimensions aren't restored
        newWindow.setFrameAutosaveName("CoreveoSettingsV3")
        // Enforce a new default frame and minimum content size
        newWindow.setFrame(NSRect(x: 0, y: 0, width: 700, height: 480), display: false)
        newWindow.contentMinSize = NSSize(width: 700, height: 480)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false // Don't auto-release
        newWindow.animationBehavior = .none
        
        // Use full SettingsView (shows Appearance + General)
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        newWindow.contentViewController = hostingController
        
        // Apply theme appearance
        newWindow.appearance = ThemeManager.shared.getAppearance()
        
        // Store reference to prevent deallocation
        self.settingsWindow = newWindow
        
        newWindow.makeKeyAndOrderFront(nil)
        }

    
}

