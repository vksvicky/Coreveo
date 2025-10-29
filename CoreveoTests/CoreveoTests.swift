@testable import Coreveo
import XCTest
import AppKit

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
}
