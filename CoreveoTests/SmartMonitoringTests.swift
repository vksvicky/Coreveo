import XCTest
@testable import Coreveo

/// TDD tests for S.M.A.R.T. disk health monitoring
/// These tests define the expected behavior before implementation
@MainActor
final class SmartMonitoringTests: XCTestCase {
    
    // MARK: - Test S.M.A.R.T. Data Reading
    
    func testSmartReader_CanDetectDisks() {
        print("\n=== Testing S.M.A.R.T. Disk Detection ===")
        
        let reader = SystemSmartReader()
        let disks = reader.getAvailableDisks()
        
        print("Detected disks: \(disks.count)")
        for disk in disks {
            print("  - \(disk.identifier): \(disk.name)")
        }
        
        // Should detect at least one disk on a Mac
        XCTAssertGreaterThan(disks.count, 0, "Should detect at least one disk")
        
        print("✅ Disk detection test passed")
        print("==========================================\n")
    }
    
    func testSmartReader_RequiresFDAForSmartData() {
        print("\n=== Testing S.M.A.R.T. FDA Requirement ===")
        
        let reader = SystemSmartReader()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        print("Full Disk Access: \(hasFDA ? "✅ GRANTED" : "❌ NOT GRANTED")")
        
        // Try to read S.M.A.R.T. data
        if let disks = reader.getAvailableDisks().first.map({ [$0] }) ?? nil, !disks.isEmpty {
            let disk = disks[0]
            print("Testing S.M.A.R.T. read for: \(disk.name)")
            
            let smartData = reader.readSmartData(for: disk)
            
            if hasFDA {
                // With FDA and IOKit/diskutil, we should ALWAYS get basic data for physical disks
                print("With FDA: \(smartData != nil ? "✅ Got data via IOKit/diskutil" : "❌ FAILED - should get data")")
                XCTAssertNotNil(smartData, "Should get basic S.M.A.R.T. data via IOKit when FDA is granted")
                
                if let data = smartData {
                    print("  Health: \(data.health)")
                    XCTAssertFalse(data.health.isEmpty, "Health status should not be empty")
                }
            } else {
                // Without FDA, we should get nil or permission error
                print("Without FDA: \(smartData == nil ? "✅ Correctly blocked" : "⚠️  Unexpected data access")")
                XCTAssertNil(smartData, "Should not be able to read S.M.A.R.T. data without FDA")
            }
        }
        
        print("==========================================\n")
    }
    
    func testSmartReader_ReturnsExpectedDataStructure() {
        print("\n=== Testing S.M.A.R.T. Data Structure ===")
        
        let reader = SystemSmartReader()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        guard hasFDA else {
            print("⚠️  Skipping: FDA not granted")
            print("==========================================\n")
            return
        }
        
        guard let disk = reader.getAvailableDisks().first else {
            print("⚠️  Skipping: No disks detected")
            print("==========================================\n")
            return
        }
        
        if let smartData = reader.readSmartData(for: disk) {
            print("S.M.A.R.T. data for \(disk.name):")
            print("  Temperature: \(smartData.temperature?.description ?? "N/A")°C")
            print("  Health: \(smartData.health)")
            print("  Power On Hours: \(smartData.powerOnHours?.description ?? "N/A")")
            print("  Wear Level: \(smartData.wearLevelPercent?.description ?? "N/A")%")
            
            // Validate data structure
            XCTAssertNotNil(smartData.health, "Health status should always be present")
            
            // Temperature should be reasonable if present
            if let temp = smartData.temperature {
                XCTAssertGreaterThan(temp, 0, "Temperature should be positive")
                XCTAssertLessThan(temp, 100, "Temperature should be less than 100°C")
            }
            
            // Wear level should be 0-100 if present
            if let wear = smartData.wearLevelPercent {
                XCTAssertGreaterThanOrEqual(wear, 0, "Wear level should be >= 0")
                XCTAssertLessThanOrEqual(wear, 100, "Wear level should be <= 100")
            }
            
            print("✅ Data structure validation passed")
        } else {
            print("⚠️  No S.M.A.R.T. data available (disk may not support it)")
        }
        
        print("==========================================\n")
    }
    
    // MARK: - Test FDA Status Checking
    
    func testSmartMonitor_ChecksFDABeforeReading() {
        print("\n=== Testing FDA Check Before S.M.A.R.T. Read ===")
        
        let monitor = SmartDiskMonitor()
        let canReadSmart = monitor.canReadSmartData()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        print("FDA Status: \(hasFDA ? "✅ GRANTED" : "❌ NOT GRANTED")")
        print("Can Read S.M.A.R.T.: \(canReadSmart ? "✅ YES" : "❌ NO")")
        
        // canReadSmartData should match FDA status
        XCTAssertEqual(canReadSmart, hasFDA, "S.M.A.R.T. availability should match FDA status")
        
        if !canReadSmart {
            let message = monitor.getFDARequiredMessage()
            print("User message: \"\(message)\"")
            XCTAssertFalse(message.isEmpty, "Should provide user-friendly message when FDA not granted")
        }
        
        print("✅ FDA check test passed")
        print("==========================================\n")
    }
    
    func testSmartMonitor_ProvidesUserFriendlyErrorMessages() {
        print("\n=== Testing User-Friendly Error Messages ===")
        
        let monitor = SmartDiskMonitor()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        if !hasFDA {
            let message = monitor.getFDARequiredMessage()
            
            print("FDA Required Message:")
            print("  \"\(message)\"")
            
            // Message should be informative
            XCTAssertTrue(message.contains("Full Disk Access") || message.contains("permission"),
                         "Message should mention Full Disk Access or permission")
            XCTAssertTrue(message.count > 20, "Message should be descriptive")
            
            print("✅ Message is user-friendly")
        } else {
            print("⚠️  FDA is granted, cannot test error message")
        }
        
        print("==========================================\n")
    }
    
    // MARK: - Test IOKit Native Reading
    
    func testSmartReader_UsesIOKitByDefault() {
        print("\n=== Testing IOKit/diskutil as Primary Method ===")
        
        let reader = SystemSmartReader()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        guard hasFDA else {
            print("⚠️  Skipping: FDA not granted")
            print("==========================================\n")
            return
        }
        
        guard let disk = reader.getAvailableDisks().first else {
            print("⚠️  Skipping: No disks detected")
            print("==========================================\n")
            return
        }
        
        print("Testing native macOS IOKit/diskutil reading for: \(disk.name)")
        
        // This should work WITHOUT smartctl installed
        let smartData = reader.readSmartData(for: disk)
        
        XCTAssertNotNil(smartData, "Should read S.M.A.R.T. data via native IOKit/diskutil (no smartctl required)")
        
        if let data = smartData {
            print("✅ Successfully read data via IOKit/diskutil:")
            print("  Health: \(data.health)")
            XCTAssertFalse(data.health.isEmpty, "Should have health status")
            print("  Note: Temperature, wear level may be nil (advanced data requires smartctl)")
        }
        
        print("==========================================\n")
    }
    
    func testSmartReader_ExtractsModelAndSerial() {
        print("\n=== Testing Model and Serial Number Extraction ===")
        
        let reader = SystemSmartReader()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        guard hasFDA else {
            print("⚠️  Skipping: FDA not granted")
            print("==========================================\n")
            return
        }
        
        guard let disk = reader.getAvailableDisks().first else {
            print("⚠️  Skipping: No disks detected")
            print("==========================================\n")
            return
        }
        
        print("Testing model/serial extraction for: \(disk.name)")
        
        let smartData = reader.readSmartData(for: disk)
        
        XCTAssertNotNil(smartData, "Should read S.M.A.R.T. data")
        
        if let data = smartData {
            print("  Model: \(data.model ?? "Not available")")
            print("  Serial: \(data.serialNumber ?? "Not available")")
            
            // Model should be available for physical disks
            XCTAssertNotNil(data.model, "Physical disk should have model information")
            XCTAssertFalse(data.model?.isEmpty ?? true, "Model should not be empty")
            
            // Serial number should be available for physical disks
            XCTAssertNotNil(data.serialNumber, "Physical disk should have serial number")
            XCTAssertFalse(data.serialNumber?.isEmpty ?? true, "Serial should not be empty")
            
            print("✅ Model and serial extracted successfully")
        }
        
        print("==========================================\n")
    }
    
    func testSmartReader_ReadsTemperature() {
        print("\n=== Testing Temperature Reading ===")
        
        let reader = SystemSmartReader()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        guard hasFDA else {
            print("⚠️  Skipping: FDA not granted")
            print("==========================================\n")
            return
        }
        
        guard let disk = reader.getAvailableDisks().first else {
            print("⚠️  Skipping: No disks detected")
            print("==========================================\n")
            return
        }
        
        print("Testing temperature reading for: \(disk.name)")
        
        let smartData = reader.readSmartData(for: disk)
        
        if let data = smartData, let temp = data.temperature {
            print("  Temperature: \(temp)°C")
            
            // Temperature should be reasonable
            XCTAssertGreaterThan(temp, 0, "Temperature should be positive")
            XCTAssertLessThan(temp, 100, "Temperature should be less than 100°C for normal operation")
            
            print("✅ Temperature reading validated")
        } else {
            print("⚠️  Temperature not available (may require IOKit enhancement)")
            // Don't fail - temperature might not be available on all disks/configurations
        }
        
        print("==========================================\n")
    }
    
    func testSmartReader_DetectsSSDWearLevel() {
        print("\n=== Testing SSD Wear Level Detection ===")
        
        let reader = SystemSmartReader()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        guard hasFDA else {
            print("⚠️  Skipping: FDA not granted")
            print("==========================================\n")
            return
        }
        
        guard let disk = reader.getAvailableDisks().first else {
            print("⚠️  Skipping: No disks detected")
            print("==========================================\n")
            return
        }
        
        print("Testing wear level detection for: \(disk.name)")
        
        let smartData = reader.readSmartData(for: disk)
        
        if let data = smartData {
            if let wearLevel = data.wearLevelPercent {
                print("  Wear Level: \(wearLevel)%")
                
                // Wear level should be 0-100
                XCTAssertGreaterThanOrEqual(wearLevel, 0, "Wear level should be >= 0")
                XCTAssertLessThanOrEqual(wearLevel, 100, "Wear level should be <= 100")
                
                print("✅ Wear level reading validated")
            } else {
                print("⚠️  Wear level not available (may be HDD or not supported)")
                // Don't fail - wear level is SSD-specific
            }
            
            if let availableSpare = data.availableSparePercent {
                print("  Available Spare: \(availableSpare)%")
                
                // Available spare should be 0-100
                XCTAssertGreaterThanOrEqual(availableSpare, 0, "Available spare should be >= 0")
                XCTAssertLessThanOrEqual(availableSpare, 100, "Available spare should be <= 100")
            }
        }
        
        print("==========================================\n")
    }
    
    func testSmartReader_TracksPowerOnHours() {
        print("\n=== Testing Power-On Hours Tracking ===")
        
        let reader = SystemSmartReader()
        let hasFDA = PermissionManager.shared.checkFullDiskAccessPermission()
        
        guard hasFDA else {
            print("⚠️  Skipping: FDA not granted")
            print("==========================================\n")
            return
        }
        
        guard let disk = reader.getAvailableDisks().first else {
            print("⚠️  Skipping: No disks detected")
            print("==========================================\n")
            return
        }
        
        print("Testing power-on hours for: \(disk.name)")
        
        let smartData = reader.readSmartData(for: disk)
        
        if let data = smartData, let powerOnHours = data.powerOnHours {
            print("  Power On Hours: \(powerOnHours) hours")
            
            // Power on hours should be positive
            XCTAssertGreaterThan(powerOnHours, 0, "Power on hours should be positive")
            
            // Convert to days for human readability
            let days = powerOnHours / 24
            print("  (≈ \(days) days)")
            
            print("✅ Power-on hours reading validated")
        } else {
            print("⚠️  Power-on hours not available")
            // Don't fail - might not be available on all systems
        }
        
        print("==========================================\n")
    }
    
    // MARK: - Test S.M.A.R.T. Data Parsing (smartctl fallback)
    
    func testSmartParser_HandlesValidData() {
        print("\n=== Testing S.M.A.R.T. Data Parsing (smartctl fallback) ===")
        
        // Test with mock smartctl output (used as fallback for comprehensive data)
        let mockOutput = """
        smartctl 7.3 2022-02-28 r5338 [Darwin 23.0.0 arm64] (local build)
        Copyright (C) 2002-22, Bruce Allen, Christian Franke, www.smartmontools.org
        
        === START OF INFORMATION SECTION ===
        Model Number:                       APPLE SSD AP0512Q
        Serial Number:                      abc123def456
        Firmware Version:                   1161.120.5
        Critical Warning:                   0x00
        Temperature:                        32 Celsius
        Available Spare:                    100%
        Available Spare Threshold:          10%
        Percentage Used:                    5%
        Data Units Read:                    12,345,678 [6.31 TB]
        Data Units Written:                 23,456,789 [12.0 TB]
        Power On Hours:                     1,234
        Power Cycles:                       567
        """
        
        let parser = SmartDataParser()
        let data = parser.parse(smartctlOutput: mockOutput)
        
        XCTAssertNotNil(data, "Should parse valid smartctl output")
        XCTAssertEqual(data?.temperature, 32, "Should extract temperature")
        XCTAssertEqual(data?.wearLevelPercent, 5, "Should extract wear level")
        XCTAssertEqual(data?.powerOnHours, 1234, "Should extract power on hours")
        XCTAssertEqual(data?.health, "Healthy", "Should determine health status")
        
        print("✅ Parser correctly handles valid data")
        print("==========================================\n")
    }
    
    func testSmartParser_HandlesInvalidData() {
        print("\n=== Testing S.M.A.R.T. Parser Error Handling (smartctl fallback) ===")
        
        let parser = SmartDataParser()
        
        // Test with empty output
        let emptyData = parser.parse(smartctlOutput: "")
        XCTAssertNil(emptyData, "Should return nil for empty output")
        
        // Test with error output
        let errorOutput = "smartctl: command not found"
        let errorData = parser.parse(smartctlOutput: errorOutput)
        XCTAssertNil(errorData, "Should return nil for error output")
        
        print("✅ Parser correctly handles invalid data")
        print("Note: This is for smartctl fallback - primary IOKit/diskutil method doesn't need parsing")
        print("==========================================\n")
    }
}

