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
    func testCompositeUsesPrimaryWhenAvailable() {
        // Given
        let primary = MockTempProvider()
        primary.valueToReturn = 55
        let fallback = MockTempProvider()
        fallback.valueToReturn = 99
        let composite = CompositeTemperatureProvider(primary: primary, fallback: fallback)

        // When
        let result = composite.cpuTemperatureC(currentCPUUsage: 12.0)

        // Then
        XCTAssertEqual(result, 55)
        XCTAssertEqual(Int(primary.lastHint), 12)
    }

    func testCompositeFallsBackWhenPrimaryNil() {
        // Given
        let primary = MockTempProvider()
        primary.valueToReturn = nil
        let fallback = MockTempProvider()
        fallback.valueToReturn = 44
        let composite = CompositeTemperatureProvider(primary: primary, fallback: fallback)

        // When
        let result = composite.cpuTemperatureC(currentCPUUsage: 20.0)

        // Then
        XCTAssertEqual(result, 44)
        XCTAssertEqual(Int(primary.lastHint), 20)
    }

    func testSystemMonitorPublishesTemperatureSensorsFromProvider() async throws {
        // Given
        struct MockSensors: TemperatureSensorsProviding {
            func readTemperatureSensors() -> [String: Double]? { ["Battery": 30, "SSD": 29] }
        }
        SystemMonitor.temperatureSensorsProvider = MockSensors()
        let monitor = SystemMonitor.shared

        // When
        await monitor.refreshNow()

        // Then
        await MainActor.run {
            XCTAssertEqual(monitor.temperatureSensors["Battery"], 30)
            XCTAssertEqual(monitor.temperatureSensors["SSD"], 29)
        }
    }
}
