import AppKit
@testable import Coreveo
import XCTest

@MainActor
final class CoreveoTests: XCTestCase {
    func testSystemMonitorInitialization() async throws {
        let monitor = SystemMonitor.shared
        XCTAssertNotNil(monitor)
    }
    
    func testSystemMonitorStartStop() async throws {
        let monitor = SystemMonitor.shared
        
        // Test that monitoring can be started and stopped
        monitor.startMonitoring()
        XCTAssertNotNil(monitor)
        
        // Wait a bit for monitoring to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        monitor.stopMonitoring()
        XCTAssertNotNil(monitor)
    }
    
    func testCPUUsageRange() async throws {
        let monitor = SystemMonitor.shared
        
        // CPU usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(monitor.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(monitor.cpuUsage, 100.0)
    }
    
    func testMemoryUsageRange() async throws {
        let monitor = SystemMonitor.shared
        
        // Memory usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(monitor.memoryUsage, 0.0)
        XCTAssertLessThanOrEqual(monitor.memoryUsage, 100.0)
    }
    
    func testDiskUsageRange() async throws {
        let monitor = SystemMonitor.shared
        
        // Disk usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(monitor.diskUsage, 0.0)
        XCTAssertLessThanOrEqual(monitor.diskUsage, 100.0)
    }
    
    // MARK: - Theme / Settings Tests
    
    func testThemePersistenceAndLoading() async throws {
        // Set a value directly in UserDefaults and ensure ThemeManager reads it
        UserDefaults.standard.set(AppTheme.dark.rawValue, forKey: "AppTheme")
        let manager = ThemeManager()
        XCTAssertEqual(manager.currentTheme, .dark)
        
        // Change to light and ensure persistence
        manager.currentTheme = .light
        let stored = UserDefaults.standard.string(forKey: "AppTheme")
        XCTAssertEqual(stored, AppTheme.light.rawValue)
    }
    
    func testThemeColorSchemeMapping() async throws {
        let manager = ThemeManager()
        manager.currentTheme = .light
        XCTAssertEqual(manager.effectiveColorScheme, .light)
        
        manager.currentTheme = .dark
        XCTAssertEqual(manager.effectiveColorScheme, .dark)
        
        manager.currentTheme = .system
        // When following system, colorScheme should be nil and appearance provided by system
        XCTAssertNil(manager.colorScheme)
    }

    // MARK: - Help Window Tests
    func testHelpWindowOpens() async throws {
        await MainActor.run {
            HelpWindowManager.showHelpWindow()
        }
        let hasHelp = NSApp.windows.contains(where: { $0.title == "Coreveo Help" })
        XCTAssertTrue(hasHelp)
        NSApp.windows.filter { $0.title == "Coreveo Help" }.forEach { $0.close() }
    }

    // MARK: - Preferences Wiring
    func testRefreshIntervalPreferenceRoundTrip() throws {
        let defaults = UserDefaults.standard
        defaults.set(1.0, forKey: "refreshIntervalSeconds")
        XCTAssertEqual(defaults.double(forKey: "refreshIntervalSeconds"), 1.0)
        defaults.set(2.0, forKey: "refreshIntervalSeconds")
        XCTAssertEqual(defaults.double(forKey: "refreshIntervalSeconds"), 2.0)
    }

    func testShowMenuBarItemPreferenceRoundTrip() throws {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "showMenuBarItem")
        XCTAssertTrue(defaults.bool(forKey: "showMenuBarItem"))
        defaults.set(false, forKey: "showMenuBarItem")
        XCTAssertFalse(defaults.bool(forKey: "showMenuBarItem"))
    }

    // MARK: - SystemMonitor stability
    func testSystemMonitorRepeatedStartStopDoesNotCrash() async throws {
        let monitor = SystemMonitor.shared
        for _ in 0..<3 {
            await MainActor.run { monitor.startMonitoring() }
            try await Task.sleep(nanoseconds: 50_000_000)
            await MainActor.run { monitor.stopMonitoring() }
        }
        XCTAssertNotNil(monitor)
    }
}
