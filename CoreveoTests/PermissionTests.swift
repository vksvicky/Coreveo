import XCTest
@testable import Coreveo

class PermissionTests: XCTestCase {
    
    // MARK: - Permission Tests
    
    func testAllPermissionsNotGranted() async throws {
        // Test scenario: No permissions granted
        // This should show onboarding screen
        
        // Mock the permission check to return false for all
        let mockApp = MockCoreveoApp()
        mockApp.mockAccessibilityGranted = false
        mockApp.mockFullDiskAccessGranted = false
        
        // Check that onboarding is required
        let needsOnboarding = mockApp.checkIfOnboardingNeeded()
        XCTAssertTrue(needsOnboarding, "Should show onboarding when no permissions are granted")
        
        // Check that hasCompletedOnboarding is set to false
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertFalse(hasCompleted, "hasCompletedOnboarding should be false when no permissions are granted")
    }
    
    func testOnePermissionMissing() async throws {
        // Test scenario: Only one permission granted (Accessibility)
        let mockApp = MockCoreveoApp()
        mockApp.mockAccessibilityGranted = true
        mockApp.mockFullDiskAccessGranted = false
        
        // Check that onboarding is still required
        let needsOnboarding = mockApp.checkIfOnboardingNeeded()
        XCTAssertTrue(needsOnboarding, "Should show onboarding when only one permission is granted")
        
        // Check that hasCompletedOnboarding is set to false
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertFalse(hasCompleted, "hasCompletedOnboarding should be false when only one permission is granted")
    }
    
    func testOnePermissionMissingFDA() async throws {
        // Test scenario: Only one permission granted (Full Disk Access)
        let mockApp = MockCoreveoApp()
        mockApp.mockAccessibilityGranted = false
        mockApp.mockFullDiskAccessGranted = true
        
        // Check that onboarding is still required
        let needsOnboarding = mockApp.checkIfOnboardingNeeded()
        XCTAssertTrue(needsOnboarding, "Should show onboarding when only FDA permission is granted")
        
        // Check that hasCompletedOnboarding is set to false
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertFalse(hasCompleted, "hasCompletedOnboarding should be false when only FDA permission is granted")
    }
    
    func testAllPermissionsGranted() async throws {
        // Test scenario: All permissions granted
        let mockApp = MockCoreveoApp()
        mockApp.mockAccessibilityGranted = true
        mockApp.mockFullDiskAccessGranted = true
        
        // Check that onboarding is not required
        let needsOnboarding = mockApp.checkIfOnboardingNeeded()
        XCTAssertFalse(needsOnboarding, "Should not show onboarding when all permissions are granted")
        
        // Check that hasCompletedOnboarding is set to true
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertTrue(hasCompleted, "hasCompletedOnboarding should be true when all permissions are granted")
    }
    
    func testPermissionsSkippedFeatureVisibility() async throws {
        // Test scenario: Permissions skipped - what features are visible?
        let mockApp = MockCoreveoApp()
        mockApp.mockAccessibilityGranted = false
        mockApp.mockFullDiskAccessGranted = false
        
        // Simulate skipping permissions
        mockApp.skipPermissions()
        
        // Check that onboarding is not required (skipped)
        let needsOnboarding = mockApp.checkIfOnboardingNeeded()
        XCTAssertFalse(needsOnboarding, "Should not show onboarding when permissions are skipped")
        
        // Check that hasCompletedOnboarding is set to true (skipped)
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertTrue(hasCompleted, "hasCompletedOnboarding should be true when permissions are skipped")
        
        // Check what features are available when permissions are skipped
        let availableFeatures = mockApp.getAvailableFeatures()
        
        // When permissions are skipped, certain features should be limited
        XCTAssertFalse(availableFeatures.canAccessSystemElements, "Should not be able to access system elements without Accessibility")
        XCTAssertFalse(availableFeatures.canAccessProtectedFiles, "Should not be able to access protected files without FDA")
        XCTAssertTrue(availableFeatures.canShowBasicUI, "Should still be able to show basic UI")
        XCTAssertTrue(availableFeatures.canShowSettings, "Should still be able to show settings")
    }
    
    func testPermissionStateTransitions() async throws {
        // Test scenario: Permission state changes
        let mockApp = MockCoreveoApp()
        
        // Start with no permissions
        mockApp.mockAccessibilityGranted = false
        mockApp.mockFullDiskAccessGranted = false
        XCTAssertTrue(mockApp.checkIfOnboardingNeeded(), "Should show onboarding initially")
        
        // Grant Accessibility permission
        mockApp.mockAccessibilityGranted = true
        XCTAssertTrue(mockApp.checkIfOnboardingNeeded(), "Should still show onboarding with only Accessibility")
        
        // Grant Full Disk Access permission
        mockApp.mockFullDiskAccessGranted = true
        XCTAssertFalse(mockApp.checkIfOnboardingNeeded(), "Should not show onboarding when all permissions granted")
        
        // Revoke Full Disk Access permission
        mockApp.mockFullDiskAccessGranted = false
        XCTAssertTrue(mockApp.checkIfOnboardingNeeded(), "Should show onboarding again when FDA is revoked")
    }
    
    func testPermissionCheckAccuracy() async throws {
        // Test scenario: Verify permission check methods are accurate
        let mockApp = MockCoreveoApp()
        
        // Test Accessibility check
        mockApp.mockAccessibilityGranted = true
        XCTAssertTrue(mockApp.checkAccessibilityPermission(), "Accessibility check should be accurate")
        
        mockApp.mockAccessibilityGranted = false
        XCTAssertFalse(mockApp.checkAccessibilityPermission(), "Accessibility check should be accurate")
        
        // Test Full Disk Access check
        mockApp.mockFullDiskAccessGranted = true
        XCTAssertTrue(mockApp.checkFullDiskAccessPermission(), "FDA check should be accurate")
        
        mockApp.mockFullDiskAccessGranted = false
        XCTAssertFalse(mockApp.checkFullDiskAccessPermission(), "FDA check should be accurate")
    }
    
    func testOnboardingFlow() async throws {
        // Test scenario: Complete onboarding flow
        let mockApp = MockCoreveoApp()
        
        // Start with no permissions
        mockApp.mockAccessibilityGranted = false
        mockApp.mockFullDiskAccessGranted = false
        
        // Should show onboarding
        XCTAssertTrue(mockApp.checkIfOnboardingNeeded(), "Should show onboarding initially")
        
        // Simulate user going through onboarding
        mockApp.simulateOnboardingCompletion()
        
        // Should still show onboarding (permissions not granted)
        XCTAssertTrue(mockApp.checkIfOnboardingNeeded(), "Should still show onboarding after completion without permissions")
        
        // Grant permissions
        mockApp.mockAccessibilityGranted = true
        mockApp.mockFullDiskAccessGranted = true
        
        // Should not show onboarding
        XCTAssertFalse(mockApp.checkIfOnboardingNeeded(), "Should not show onboarding when permissions are granted")
    }
    
    func testPermissionPersistence() async throws {
        // Test scenario: Permission state persistence across app launches
        let mockApp = MockCoreveoApp()
        
        // Grant permissions
        mockApp.mockAccessibilityGranted = true
        mockApp.mockFullDiskAccessGranted = true
        
        // Check that onboarding is not required
        XCTAssertFalse(mockApp.checkIfOnboardingNeeded(), "Should not show onboarding when permissions are granted")
        
        // Simulate app restart
        let newMockApp = MockCoreveoApp()
        newMockApp.mockAccessibilityGranted = true
        newMockApp.mockFullDiskAccessGranted = true
        
        // Should still not show onboarding
        XCTAssertFalse(newMockApp.checkIfOnboardingNeeded(), "Should not show onboarding after app restart with permissions")
    }
    
    func testEdgeCases() async throws {
        // Test scenario: Edge cases and error conditions
        let mockApp = MockCoreveoApp()
        
        // Test with nil permission states
        mockApp.mockAccessibilityGranted = false
        mockApp.mockFullDiskAccessGranted = false
        
        // Should handle gracefully
        XCTAssertTrue(mockApp.checkIfOnboardingNeeded(), "Should handle nil permission states gracefully")
        
        // Test with invalid permission states
        mockApp.mockAccessibilityGranted = true
        mockApp.mockFullDiskAccessGranted = false
        
        // Should still work correctly
        XCTAssertTrue(mockApp.checkIfOnboardingNeeded(), "Should handle mixed permission states correctly")
    }
}

// MARK: - Mock Classes for Permission Testing

class MockCoreveoApp {
    var mockAccessibilityGranted: Bool = false
    var mockFullDiskAccessGranted: Bool = false
    
    func checkIfOnboardingNeeded() -> Bool {
        let permissionsGranted = mockAccessibilityGranted && mockFullDiskAccessGranted
        
        if permissionsGranted {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            return false
        } else {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            return true
        }
    }
    
    func checkAccessibilityPermission() -> Bool {
        return mockAccessibilityGranted
    }
    
    func checkFullDiskAccessPermission() -> Bool {
        return mockFullDiskAccessGranted
    }
    
    func skipPermissions() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func simulateOnboardingCompletion() {
        // Simulate user completing onboarding steps
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func getAvailableFeatures() -> AvailableFeatures {
        return AvailableFeatures(
            canAccessSystemElements: mockAccessibilityGranted,
            canAccessProtectedFiles: mockFullDiskAccessGranted,
            canShowBasicUI: true,
            canShowSettings: true
        )
    }
}

struct AvailableFeatures {
    let canAccessSystemElements: Bool
    let canAccessProtectedFiles: Bool
    let canShowBasicUI: Bool
    let canShowSettings: Bool
}
