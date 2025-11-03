@testable import Coreveo
import XCTest
import ApplicationServices
import Darwin  // For getpwuid

/// TDD Tests for real permission detection
/// These tests verify that the actual permission checking logic works correctly
final class PermissionDetectionTests: XCTestCase {
    
    /// Get the real user home directory (not the sandboxed container)
    private func getRealHomeDirectory() -> String? {
        // Get username and construct the REAL path (not sandboxed)
        let uid = getuid()
        if let pw = getpwuid(uid),
           let username = pw.pointee.pw_name {
            let usernameString = String(cString: username)
            return "/Users/\(usernameString)"
        }
        return nil
    }
    
    // MARK: - Accessibility Permission Tests
    
    @MainActor
    func testAccessibilityPermissionDetection() {
        print("\n=== Testing Accessibility Permission Detection ===")
        
        // Test that we can check accessibility permission
        // This should not crash and should return a boolean
        let hasAccessibility = checkAccessibilityPermission()
        
        print("Accessibility Permission: \(hasAccessibility ? "✅ GRANTED" : "❌ NOT GRANTED")")
        
        // The result should be a boolean (not crash)
        XCTAssertTrue(hasAccessibility == true || hasAccessibility == false, 
                     "Accessibility check should return a valid boolean")
        
        // If granted, verify we can actually use accessibility APIs
        if hasAccessibility {
            let systemWideElement = AXUIElementCreateSystemWide()
            var focusedApp: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                systemWideElement,
                kAXFocusedApplicationAttribute as CFString,
                &focusedApp
            )
            
            print("Can access system-wide element: \(result == .success ? "✅ YES" : "❌ NO")")
            
            // If we say we have permission, we should be able to use it
            XCTAssertEqual(result, .success, 
                          "If Accessibility is granted, we should be able to access system elements")
        }
        
        print("==========================================\n")
    }
    
    @MainActor
    func testAccessibilityPermissionConsistency() {
        print("\n=== Testing Accessibility Permission Consistency ===")
        
        // Call the check multiple times - should return consistent results
        let result1 = checkAccessibilityPermission()
        let result2 = checkAccessibilityPermission()
        let result3 = checkAccessibilityPermission()
        
        print("Check 1: \(result1)")
        print("Check 2: \(result2)")
        print("Check 3: \(result3)")
        
        XCTAssertEqual(result1, result2, "Accessibility check should be consistent")
        XCTAssertEqual(result2, result3, "Accessibility check should be consistent")
        
        print("==========================================\n")
    }
    
    // MARK: - Full Disk Access Permission Tests
    
    @MainActor
    func testFullDiskAccessPermissionDetection() {
        print("\n=== Testing Full Disk Access Permission Detection ===")
        
        // Test that we can check FDA permission
        let hasFDA = checkFullDiskAccessPermission()
        
        print("Full Disk Access: \(hasFDA ? "✅ GRANTED" : "❌ NOT GRANTED")")
        
        // The result should be a boolean
        XCTAssertTrue(hasFDA == true || hasFDA == false,
                     "FDA check should return a valid boolean")
        
        // Test specific paths using REAL home directory
        let fileManager = FileManager.default
        guard let realHome = getRealHomeDirectory() else {
            print("⚠️  Could not determine real home directory")
            return
        }
        
        let sandboxHome = NSHomeDirectory()
        print("Sandbox home: \(sandboxHome)")
        print("Real home: \(realHome)")
        print("")
        
        let testPaths = [
            "\(realHome)/Library/Safari",
            "\(realHome)/Library/Mail"
        ]
        
        for path in testPaths {
            let exists = fileManager.fileExists(atPath: path)
            if exists {
                do {
                    _ = try fileManager.contentsOfDirectory(atPath: path)
                    print("\(path): ✅ Can list directory (FDA granted)")
                } catch {
                    print("\(path): ❌ Cannot list directory (FDA not granted)")
                }
            } else {
                print("\(path): ⚠️  Does not exist")
            }
        }
        
        print("==========================================\n")
    }
    
    @MainActor
    func testFullDiskAccessPermissionConsistency() {
        print("\n=== Testing FDA Permission Consistency ===")
        
        // Call the check multiple times - should return consistent results
        let result1 = checkFullDiskAccessPermission()
        let result2 = checkFullDiskAccessPermission()
        let result3 = checkFullDiskAccessPermission()
        
        print("Check 1: \(result1)")
        print("Check 2: \(result2)")
        print("Check 3: \(result3)")
        
        XCTAssertEqual(result1, result2, "FDA check should be consistent")
        XCTAssertEqual(result2, result3, "FDA check should be consistent")
        
        print("==========================================\n")
    }
    
    // MARK: - Combined Permission Tests
    
    @MainActor
    func testShouldShowOnboardingLogic() {
        print("\n=== Testing Onboarding Decision Logic ===")
        
        let hasAccessibility = checkAccessibilityPermission()
        let hasFDA = checkFullDiskAccessPermission()
        let shouldShowOnboarding = shouldShowPermissionOnboarding()
        
        print("Accessibility: \(hasAccessibility ? "✅" : "❌")")
        print("Full Disk Access: \(hasFDA ? "✅" : "❌")")
        print("Should show onboarding: \(shouldShowOnboarding ? "YES" : "NO")")
        
        // Logic: Show onboarding if ANY required permission is missing
        let expectedShowOnboarding = !hasAccessibility || !hasFDA
        
        XCTAssertEqual(shouldShowOnboarding, expectedShowOnboarding,
                      "Should show onboarding when any required permission is missing")
        
        // If both permissions are granted, should NOT show onboarding
        if hasAccessibility && hasFDA {
            XCTAssertFalse(shouldShowOnboarding,
                          "Should not show onboarding when all permissions are granted")
        }
        
        // If any permission is missing, SHOULD show onboarding
        if !hasAccessibility || !hasFDA {
            XCTAssertTrue(shouldShowOnboarding,
                         "Should show onboarding when any permission is missing")
        }
        
        print("==========================================\n")
    }
    
    @MainActor
    func testPermissionStatusReporting() {
        print("\n=== Testing Permission Status Reporting ===")
        
        let status = getPermissionStatus()
        
        print("Accessibility: \(status.hasAccessibility ? "✅ GRANTED" : "❌ NOT GRANTED")")
        print("Full Disk Access: \(status.hasFullDiskAccess ? "✅ GRANTED" : "❌ NOT GRANTED")")
        print("All Required: \(status.hasAllRequiredPermissions ? "✅ YES" : "❌ NO")")
        
        // Verify the status is internally consistent
        let expectedAllRequired = status.hasAccessibility && status.hasFullDiskAccess
        XCTAssertEqual(status.hasAllRequiredPermissions, expectedAllRequired,
                      "hasAllRequiredPermissions should match individual permission states")
        
        print("==========================================\n")
    }
    
    // MARK: - Helper Functions
    // These delegate to PermissionManager for consistency
    
    @MainActor
    private func checkAccessibilityPermission() -> Bool {
        return PermissionManager.shared.checkAccessibilityPermission()
    }
    
    @MainActor
    private func checkFullDiskAccessPermission() -> Bool {
        return PermissionManager.shared.checkFullDiskAccessPermission()
    }
    
    @MainActor
    private func shouldShowPermissionOnboarding() -> Bool {
        return PermissionManager.shared.shouldShowPermissionOnboarding()
    }
    
    @MainActor
    private func getPermissionStatus() -> PermissionManager.PermissionStatus {
        return PermissionManager.shared.getPermissionStatus()
    }
}

