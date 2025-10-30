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
        
        // Required permissions for basic system monitoring
        let isAccessibilityGranted = checkAccessibilityPermission()
        let isFullDiskAccessGranted = checkFullDiskAccessPermission()
        
        // Network permission is not required for basic system monitoring
        // (only needed if we ship Network Extension components, which we don't)
        let isNetworkGranted = checkNetworkPermission()
        
        NSLog("[App] Permission check - Accessibility: \(isAccessibilityGranted), Full Disk Access: \(isFullDiskAccessGranted), Network: \(isNetworkGranted) (not required)")
        
        // Only require Accessibility and Full Disk Access for basic functionality
        // Network permission is optional and treated as granted if not applicable
        return isAccessibilityGranted && isFullDiskAccessGranted
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
        NSLog("[App] Starting Accessibility permission check...")
        
        // Method 1: Standard check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSLog("[App] Accessibility standard check: \(isTrusted)")
        
        if isTrusted {
            NSLog("[App] ✅ Accessibility permission GRANTED (standard check)")
            return true
        }
        
        // Method 2: Try to create an accessibility element (works in sandboxed apps when granted)
        let appElement = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &value)
        if result == .success {
            NSLog("[App] ✅ Accessibility permission GRANTED (element creation)")
            return true
        } else {
            NSLog("[App] ❌ Accessibility element creation: FAILED (\(result.rawValue))")
        }
        
        // Method 2b: System-wide element capability check
        // If we can query the focused application from the system-wide AX element,
        // accessibility is effectively granted.
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let systemWideResult = AXUIElementCopyAttributeValue(systemWideElement,
                                                             kAXFocusedApplicationAttribute as CFString,
                                                             &focusedApp)
        if systemWideResult == .success {
            NSLog("[App] ✅ Accessibility permission GRANTED (system-wide focused app)")
            return true
        } else {
            NSLog("[App] ❌ System-wide AX check failed (code \(systemWideResult.rawValue))")
        }
        
        // Method 3: Check if we can access window information
        if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) {
            let windows = windowList as? [[String: Any]] ?? []
            NSLog("[App] Accessibility window access: \(windows.count) windows visible")
            // If we can see window info, we likely have accessibility
            if !windows.isEmpty {
                NSLog("[App] ✅ Accessibility permission GRANTED (window access)")
                return true
            }
        }
        
        NSLog("[App] ❌ Accessibility permission NOT GRANTED (all methods failed)")
        return false
    }
    
    private func checkFullDiskAccessPermission() -> Bool {
        NSLog("[App] Checking Full Disk Access...")
        
        let fileManager = FileManager.default
        
        // Get the REAL user home directory using getpwuid (not the sandboxed one)
        guard let realHome = CoreveoApp.getRealHomeDirectory() else {
            NSLog("[App] ⚠️ Could not determine real home directory")
            return false
        }
        
        NSLog("[App] Real home directory: \(realHome)")
        NSLog("[App] Sandbox home directory: \(NSHomeDirectory())")
        
        // Test multiple protected paths - only need one to succeed
        // Try more reliable paths that are more likely to exist
        let protectedPaths = [
            "\(realHome)/Library/Mail/V2/MailData",       // Mail data - requires FDA (more specific)
            "\(realHome)/Library/Safari",                  // Safari data - requires FDA
            "\(realHome)/Library/Calendars",               // Calendar data - requires FDA
            "\(realHome)/Library/Application Support/com.apple.sharedfilelist", // Shared file lists - requires FDA
            "\(realHome)/Library/Keychains",               // Keychains - requires FDA
            "\(realHome)/Library/Application Support/com.apple.TCC", // TCC database - requires FDA
            "/private/var/log/system.log"                   // System log - requires FDA (absolute path)
        ]
        
        for path in protectedPaths {
            NSLog("[App] Testing FDA path: \(path)")
            
            // Check if path exists first
            guard fileManager.fileExists(atPath: path) else {
                NSLog("[App]   Path doesn't exist (skipping)")
                continue
            }
            
            do {
                // Try to read directory contents or file attributes
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        let contents = try fileManager.contentsOfDirectory(atPath: path)
                        NSLog("[App] ✅ Full Disk Access GRANTED - accessed directory \(path) (\(contents.count) items)")
                        return true
                    } else {
                        // It's a file, try to read attributes
                        _ = try fileManager.attributesOfItem(atPath: path)
                        NSLog("[App] ✅ Full Disk Access GRANTED - accessed file \(path)")
                return true
            }
        }
            } catch let error as NSError {
                NSLog("[App]   ❌ Access denied: \(error.domain) code:\(error.code) - \(error.localizedDescription)")
                
                // Check for specific permission denied errors
                // NSCocoaErrorDomain 257 = NSFileReadNoPermissionError
                // NSCocoaErrorDomain 513 = NSFileWriteNoPermissionError  
                // NSPOSIXErrorDomain 13 = Permission denied
                if (error.domain == NSCocoaErrorDomain && (error.code == 257 || error.code == 513)) ||
                   (error.domain == NSPOSIXErrorDomain && error.code == 13) {
                    NSLog("[App]   This is a permission denied error (expected without FDA)")
                } else {
                    // Other errors might indicate permission denied too
                    NSLog("[App]   Unexpected error - might indicate permission denied")
                }
            }
        }
        
        NSLog("[App] ❌ Full Disk Access NOT GRANTED - could not access any protected paths")
        return false
    }

    private func checkNetworkPermission() -> Bool {
        // Mirrors onboarding logic: if we don't bundle any Network Extension
        // components, then permission is not required → treat as granted.
        let fileManager = FileManager.default
        var hasNetworkExtensions = false
        
        if let pluginsURL = Bundle.main.builtInPlugInsURL,
           let pluginItems = try? fileManager.contentsOfDirectory(
               at: pluginsURL,
               includingPropertiesForKeys: nil,
               options: [.skipsHiddenFiles]
           ) {
            if pluginItems.contains(where: { $0.pathExtension == "appex" }) {
                hasNetworkExtensions = true
            }
        }
        
        let systemExtensionsPath = (Bundle.main.bundlePath as NSString)
            .appendingPathComponent("Contents/Library/SystemExtensions")
        if fileManager.fileExists(atPath: systemExtensionsPath) {
            hasNetworkExtensions = true
        }
        
        // If no NE components, treat as granted; otherwise, require user action
        let granted = !hasNetworkExtensions ? true : false
        return granted
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

