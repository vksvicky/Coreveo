@testable import Coreveo
import XCTest

@MainActor
final class CoreveoTests: XCTestCase {
    func testSystemMonitorInitialization() async throws {
        let monitor = SystemMonitor()
        XCTAssertNotNil(monitor)
        XCTAssertEqual(monitor.cpuUsage, 0.0)
        XCTAssertEqual(monitor.memoryUsage, 0.0)
        XCTAssertEqual(monitor.diskUsage, 0.0)
    }
    
    func testSystemMonitorStartStop() async throws {
        let monitor = SystemMonitor()
        
        // Test that monitoring can be started and stopped
        monitor.startMonitoring()
        XCTAssertNotNil(monitor)
        
        // Wait a bit for monitoring to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        monitor.stopMonitoring()
        XCTAssertNotNil(monitor)
    }
    
    func testCPUUsageRange() async throws {
        let monitor = SystemMonitor()
        
        // CPU usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(monitor.cpuUsage, 0.0)
        XCTAssertLessThanOrEqual(monitor.cpuUsage, 100.0)
    }
    
    func testMemoryUsageRange() async throws {
        let monitor = SystemMonitor()
        
        // Memory usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(monitor.memoryUsage, 0.0)
        XCTAssertLessThanOrEqual(monitor.memoryUsage, 100.0)
    }
    
    func testDiskUsageRange() async throws {
        let monitor = SystemMonitor()
        
        // Disk usage should be between 0 and 100
        XCTAssertGreaterThanOrEqual(monitor.diskUsage, 0.0)
        XCTAssertLessThanOrEqual(monitor.diskUsage, 100.0)
    }
}
