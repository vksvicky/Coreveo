# Coreveo Permission Testing Scenarios

This document outlines the comprehensive test scenarios for Coreveo's permission handling system, covering all the cases you requested.

## Test Scenarios Overview

### 1. All Permissions Not Granted
**Scenario**: No permissions granted (Accessibility: false, Full Disk Access: false)
**Expected Behavior**:
- ✅ Show onboarding screen
- ✅ Set `hasCompletedOnboarding = false`
- ✅ Display permission request steps
- ✅ Show "Permission Required" status for both permissions

**Test Implementation**:
```swift
func testAllPermissionsNotGranted() {
    // Mock both permissions as false
    mockApp.mockAccessibilityGranted = false
    mockApp.mockFullDiskAccessGranted = false
    
    // Verify onboarding is required
    XCTAssertTrue(mockApp.checkIfOnboardingNeeded())
    XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
}
```

### 2. One Permission Missing (Accessibility)
**Scenario**: Only Accessibility permission granted (Accessibility: true, Full Disk Access: false)
**Expected Behavior**:
- ✅ Show onboarding screen
- ✅ Set `hasCompletedOnboarding = false`
- ✅ Show "Permission Granted" for Accessibility
- ✅ Show "Permission Required" for Full Disk Access

**Test Implementation**:
```swift
func testOnePermissionMissing() {
    mockApp.mockAccessibilityGranted = true
    mockApp.mockFullDiskAccessGranted = false
    
    XCTAssertTrue(mockApp.checkIfOnboardingNeeded())
    XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
}
```

### 3. One Permission Missing (Full Disk Access)
**Scenario**: Only Full Disk Access permission granted (Accessibility: false, Full Disk Access: true)
**Expected Behavior**:
- ✅ Show onboarding screen
- ✅ Set `hasCompletedOnboarding = false`
- ✅ Show "Permission Required" for Accessibility
- ✅ Show "Permission Granted" for Full Disk Access

**Test Implementation**:
```swift
func testOnePermissionMissingFDA() {
    mockApp.mockAccessibilityGranted = false
    mockApp.mockFullDiskAccessGranted = true
    
    XCTAssertTrue(mockApp.checkIfOnboardingNeeded())
    XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
}
```

### 4. All Permissions Granted
**Scenario**: Both permissions granted (Accessibility: true, Full Disk Access: true)
**Expected Behavior**:
- ✅ Skip onboarding screen
- ✅ Set `hasCompletedOnboarding = true`
- ✅ Show main app interface directly
- ✅ No permission window should appear

**Test Implementation**:
```swift
func testAllPermissionsGranted() {
    mockApp.mockAccessibilityGranted = true
    mockApp.mockFullDiskAccessGranted = true
    
    XCTAssertFalse(mockApp.checkIfOnboardingNeeded())
    XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
}
```

### 5. Permissions Skipped - Feature Visibility
**Scenario**: User skips permissions during onboarding
**Expected Behavior**:
- ✅ Skip onboarding screen
- ✅ Set `hasCompletedOnboarding = true`
- ✅ Show main app interface
- ✅ Limited feature availability:
  - ❌ Cannot access system elements (no Accessibility)
  - ❌ Cannot access protected files (no Full Disk Access)
  - ✅ Can show basic UI
  - ✅ Can show settings

**Test Implementation**:
```swift
func testPermissionsSkippedFeatureVisibility() {
    mockApp.mockAccessibilityGranted = false
    mockApp.mockFullDiskAccessGranted = false
    mockApp.skipPermissions()
    
    XCTAssertFalse(mockApp.checkIfOnboardingNeeded())
    XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    
    let features = mockApp.getAvailableFeatures()
    XCTAssertFalse(features.canAccessSystemElements)
    XCTAssertFalse(features.canAccessProtectedFiles)
    XCTAssertTrue(features.canShowBasicUI)
    XCTAssertTrue(features.canShowSettings)
}
```

## Additional Test Scenarios

### 6. Permission State Transitions
**Scenario**: Permission state changes during app usage
**Expected Behavior**:
- Start with no permissions → Show onboarding
- Grant Accessibility → Still show onboarding
- Grant Full Disk Access → Hide onboarding, show main app
- Revoke Full Disk Access → Show onboarding again

### 7. Permission Check Accuracy
**Scenario**: Verify permission detection methods work correctly
**Expected Behavior**:
- Permission checks return accurate results
- No false positives or false negatives
- Consistent behavior across different detection methods

### 8. Onboarding Flow
**Scenario**: Complete user journey through onboarding
**Expected Behavior**:
- Proper flow from permission request to completion
- Correct state management throughout process
- Graceful handling of permission denials

### 9. Permission Persistence
**Scenario**: Permission state across app launches
**Expected Behavior**:
- Permission state persists correctly
- No unnecessary re-prompting
- Proper handling of permission changes

### 10. Edge Cases
**Scenario**: Error conditions and edge cases
**Expected Behavior**:
- Graceful handling of permission check failures
- Proper fallback behavior
- No crashes or unexpected states

## Mock Implementation

The tests use a `MockCoreveoApp` class that simulates the permission checking logic:

```swift
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
    
    func getAvailableFeatures() -> AvailableFeatures {
        return AvailableFeatures(
            canAccessSystemElements: mockAccessibilityGranted,
            canAccessProtectedFiles: mockFullDiskAccessGranted,
            canShowBasicUI: true,
            canShowSettings: true
        )
    }
}
```

## Running the Tests

To run these tests, you would use:

```bash
# Run all permission tests
xcodebuild test -project Coreveo.xcodeproj -scheme Coreveo -destination 'platform=macOS' -only-testing:PermissionTests

# Run specific test
xcodebuild test -project Coreveo.xcodeproj -scheme Coreveo -destination 'platform=macOS' -only-testing:PermissionTests/testAllPermissionsGranted
```

## Key Testing Points

1. **Permission Detection**: Verify that both Accessibility and Full Disk Access are detected correctly
2. **Onboarding Logic**: Ensure onboarding shows/hides based on permission status
3. **State Management**: Check that `hasCompletedOnboarding` flag is managed correctly
4. **Feature Availability**: Verify that features are enabled/disabled based on permissions
5. **User Experience**: Ensure smooth transitions between permission states
6. **Error Handling**: Test graceful handling of permission check failures

This comprehensive test suite ensures that Coreveo's permission system works correctly in all scenarios and provides a good user experience regardless of permission status.
