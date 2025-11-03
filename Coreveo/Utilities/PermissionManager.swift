import Foundation
import ApplicationServices
import AppKit
import Darwin  // For getpwuid to get real home directory

/// Centralized permission management
/// Single source of truth for all permission checking across the app
final class PermissionManager {
    
    // MARK: - Singleton
    
    static let shared = PermissionManager()
    
    private init() {}
    
    // MARK: - Permission Status
    
    struct PermissionStatus {
        let hasAccessibility: Bool
        let hasFullDiskAccess: Bool
        
        var hasAllRequiredPermissions: Bool {
            return hasAccessibility && hasFullDiskAccess
        }
    }
    
    // MARK: - Public API
    
    /// Get current permission status
    func getPermissionStatus() -> PermissionStatus {
        return PermissionStatus(
            hasAccessibility: checkAccessibilityPermission(),
            hasFullDiskAccess: checkFullDiskAccessPermission()
        )
    }
    
    /// Check if we need to show permission onboarding
    /// Returns true if ANY required permission is missing
    func shouldShowPermissionOnboarding() -> Bool {
        let status = getPermissionStatus()
        return !status.hasAllRequiredPermissions
    }
    
    // MARK: - Accessibility Permission
    
    /// Check if Accessibility permission is granted
    /// Uses multiple detection methods for reliability:
    /// 1. Standard AXIsProcessTrusted check
    /// 2. System-wide element capability check
    nonisolated func checkAccessibilityPermission() -> Bool {
        // Method 1: Standard check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if isTrusted {
            return true
        }
        
        // Method 2: Try to access system-wide element
        // This is a more reliable check in some scenarios
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        
        return result == .success
    }
    
    /// Request Accessibility permission (shows system prompt)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Full Disk Access Permission
    
    /// Get the real user home directory (not the sandboxed container)
    nonisolated private func getRealHomeDirectory() -> String? {
        // Method 1: Get username and construct path
        // This works even in sandboxed apps because we construct the REAL path
        let uid = getuid()
        if let pw = getpwuid(uid),
           let username = pw.pointee.pw_name {
            let usernameString = String(cString: username)
            return "/Users/\(usernameString)"
        }
        
        // Method 2: Try environment variable (but this may be sandboxed)
        if let homeFromEnv = ProcessInfo.processInfo.environment["HOME"],
           !homeFromEnv.contains("/Containers/") {
            return homeFromEnv
        }
        
        return nil
    }
    
    /// Check if Full Disk Access permission is granted
    /// Uses directory listing as a reliable FDA check across Intel/Silicon and macOS 14+
    /// Tests multiple protected directories to ensure compatibility
    nonisolated func checkFullDiskAccessPermission() -> Bool {
        let fileManager = FileManager.default
        
        // Get the REAL home directory, not the sandboxed container path
        guard let home = getRealHomeDirectory() else {
            return false
        }
        
        // Priority 1: Test directories that REQUIRE FDA (work on both Intel and Silicon, macOS 14+)
        // These are most reliable across different configurations
        let primaryPaths = [
            "\(home)/Library/Mail",           // Most reliable - exists on most systems
            "\(home)/Library/Calendars",      // Also reliable
            "\(home)/Library/Messages"        // Messages requires FDA
        ]
        
        // Priority 2: Fallback paths for systems where primary paths don't exist
        let fallbackPaths = [
            "\(home)/Library/Safari",                                           // Safari (may not exist in sandbox)
            "\(home)/Library/Application Support/com.apple.TCC/TCC.db",       // User TCC DB
            "/Library/Application Support/com.apple.TCC/TCC.db"                // System TCC DB (may not require FDA on all systems)
        ]
        
        // Try primary paths first
        for path in primaryPaths {
            if let result = testFDAPath(path, fileManager: fileManager) {
                return result
            }
        }
        
        // Try fallback paths
        for path in fallbackPaths {
            if let result = testFDAPath(path, fileManager: fileManager) {
                return result
            }
        }
        
        // If no paths could be tested, assume FDA is NOT granted to be safe
        return false
    }
    
    /// Test a single path for FDA access
    /// Returns: true if FDA granted, false if denied, nil if path doesn't exist
    nonisolated private func testFDAPath(_ path: String, fileManager: FileManager) -> Bool? {
        // Check if path exists
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        
        // Check if it's a directory or file
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        
        do {
            if isDirectory.boolValue {
                // Try to list directory contents - this requires FDA for protected dirs
                _ = try fileManager.contentsOfDirectory(atPath: path)
                return true
            } else {
                // Try to read file attributes - this requires FDA for protected files
                _ = try fileManager.attributesOfItem(atPath: path)
                return true
            }
        } catch let error as NSError {
            // Check for permission denied error specifically
            if error.domain == NSCocoaErrorDomain && error.code == 257 {
                return false
            } else {
                // Other errors - treat as "cannot determine"
                return nil
            }
        }
    }
    
    /// Open System Settings to Full Disk Access pane
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

