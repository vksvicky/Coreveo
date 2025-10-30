import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics
import Darwin

/// Permissions settings tab
struct PermissionsSettingsView: View {
    @State private var accessibilityGranted = false
    @State private var fullDiskAccessGranted = false
    @State private var isChecking = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permissions")
                        .font(.system(size: 34, weight: .bold))
                    
                    Text("Manage system permissions required for Coreveo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    PermissionRowView(
                        title: "Accessibility Permission",
                        description: "Required for process monitoring and system control",
                        icon: "person.crop.circle",
                        isGranted: accessibilityGranted,
                        onRequest: {
                            requestAccessibilityPermission()
                        },
                        onOpenSettings: {
                            openAccessibilitySettings()
                        }
                    )
                    
                    PermissionRowView(
                        title: "Full Disk Access",
                        description: "Required for disk monitoring and S.M.A.R.T. data",
                        icon: "externaldrive.fill",
                        isGranted: fullDiskAccessGranted,
                        onRequest: {
                            requestFullDiskAccess()
                        },
                        onOpenSettings: {
                            openFullDiskAccessSettings()
                        }
                    )
                }
                
                Spacer(minLength: 20)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Refresh permissions when app becomes active (user may have changed them in System Settings)
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        accessibilityGranted = checkAccessibilityPermission()
        fullDiskAccessGranted = checkFullDiskAccessPermission()
    }
    
    private func checkAccessibilityPermission() -> Bool {
        // Method 1: Standard check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if isTrusted {
            return true
        }
        
        // Method 2: Try to create an accessibility element
        let appElement = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &value)
        if result == .success {
            return true
        }
        
        // Method 3: System-wide element capability check
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let systemWideResult = AXUIElementCopyAttributeValue(systemWideElement,
                                                             kAXFocusedApplicationAttribute as CFString,
                                                             &focusedApp)
        if systemWideResult == .success {
            return true
        }
        
        // Method 4: Check if we can access window information
        if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) {
            let windows = windowList as? [[String: Any]] ?? []
            if !windows.isEmpty {
                return true
            }
        }
        
        return false
    }
    
    private func checkFullDiskAccessPermission() -> Bool {
        let fileManager = FileManager.default
        
        guard let realHome = getRealHomeDirectory() else {
            return false
        }
        
        let protectedPaths = [
            "\(realHome)/Library/Mail/V2/MailData",
            "\(realHome)/Library/Safari",
            "\(realHome)/Library/Calendars",
            "\(realHome)/Library/Application Support/com.apple.sharedfilelist",
            "\(realHome)/Library/Keychains",
            "\(realHome)/Library/Application Support/com.apple.TCC",
            "/private/var/log/system.log"
        ]
        
        for path in protectedPaths {
            guard fileManager.fileExists(atPath: path) else {
                continue
            }
            
            do {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        _ = try fileManager.contentsOfDirectory(atPath: path)
                        return true
                    } else {
                        _ = try fileManager.attributesOfItem(atPath: path)
                        return true
                    }
                }
            } catch {
                // Permission denied - continue checking other paths
            }
        }
        
        return false
    }
    
    private func getRealHomeDirectory() -> String? {
        if let homeFromEnv = ProcessInfo.processInfo.environment["HOME"] {
            return homeFromEnv
        }
        
        let uid = getuid()
        if let pw = getpwuid(uid),
           let homeDir = pw.pointee.pw_dir {
            return String(cString: homeDir)
        }
        
        return nil
    }
    
    private func requestAccessibilityPermission() {
        // Trigger the system prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // Also open System Settings
        openAccessibilitySettings()
        
        // Poll for changes
        isChecking = true
        pollPermission(type: .accessibility)
    }
    
    private func requestFullDiskAccess() {
        // Attempt to trigger TCC prompt by accessing a protected file
        triggerFullDiskAccessPrompt()
        
        // Open System Settings
        openFullDiskAccessSettings()
        
        // Poll for changes
        isChecking = true
        pollPermission(type: .fullDiskAccess)
    }
    
    private func triggerFullDiskAccessPrompt() {
        guard let realHome = getRealHomeDirectory() else {
            return
        }
        
        let fileManager = FileManager.default
        let testPaths = [
            "\(realHome)/Library/Mail/V2/MailData/Envelope Index",
            "\(realHome)/Library/Safari/History.db",
            "\(realHome)/Library/Calendars/Calendar Cache",
            "\(realHome)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentItems.sfl",
            "\(realHome)/Library/Mail",
            "\(realHome)/Library/Safari"
        ]
        
        for path in testPaths {
            if fileManager.fileExists(atPath: path) {
                do {
                    _ = try fileManager.attributesOfItem(atPath: path)
                } catch {
                    // Expected error - triggers TCC prompt
                }
            } else {
                let parentDir = (path as NSString).deletingLastPathComponent
                if fileManager.fileExists(atPath: parentDir) {
                    do {
                        _ = try fileManager.contentsOfDirectory(atPath: parentDir)
                    } catch {
                        // Expected error - triggers TCC prompt
                    }
                }
            }
        }
    }
    
    private enum PermissionType {
        case accessibility
        case fullDiskAccess
    }
    
    private func pollPermission(type: PermissionType, attempts: Int = 20) {
        guard attempts > 0 else {
            isChecking = false
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkPermissions()
            
            let granted = type == .accessibility ? accessibilityGranted : fullDiskAccessGranted
            if granted {
                isChecking = false
            } else {
                pollPermission(type: type, attempts: attempts - 1)
            }
        }
    }
    
    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(fallback)
        }
    }
}

