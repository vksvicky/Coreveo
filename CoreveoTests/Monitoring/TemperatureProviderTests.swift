@testable import Coreveo
import XCTest

private final class MockTempProvider: TemperatureProviding {
    var lastHint: Double = -1
    var valueToReturn: Double? = 42
    func cpuTemperatureC(currentCPUUsage: Double) -> Double? {
        lastHint = currentCPUUsage
        return valueToReturn
    }
}

final class TemperatureProviderTests: XCTestCase {
    func testSystemMonitorPublishesTemperatureFromProvider() async throws {
        // Arrange
        let mock = MockTempProvider()
        SystemMonitor.temperatureProvider = mock
        let monitor = SystemMonitor.shared
        await MainActor.run { monitor.cpuUsage = 33.0 }

        // Act
        await monitor.test_updateTemperatureOnce()

        // Assert
        await MainActor.run {
            XCTAssertEqual(Int(monitor.temperature), 42)
        }
        XCTAssertEqual(Int(mock.lastHint), 33)
    }
}


