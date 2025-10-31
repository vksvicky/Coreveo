@testable import Coreveo
import XCTest

private final class MockSMC: SMCClient {
    var temps: [String: Double]? = [
        "TC0E": 45, // Efficiency Core 0 (-> 0 or 1 based on mapping)
        "TC1P": 40, // Performance Core 1
        "TG0D": 44, // GPU cluster
        "TB0T": 29  // Battery
    ]
    var fans: [Double]? = [0, 0]
    func readTemperaturesC() -> [String: Double]? { temps }
    func readFanRPMs() -> [Double]? { fans }
}

final class SMCProvidersTests: XCTestCase {
    func testSMCTemperatureSensorsProviderMapsFriendlyNames() {
        let mock = MockSMC()
        let provider = SMCTemperatureSensorsProvider(smc: mock)
        let result = provider.readTemperatureSensors()
        XCTAssertNotNil(result)
        guard let map = result else {
            XCTFail("Expected non-nil result")
            return
        }
        XCTAssertEqual(map["GPU Cluster"], 44)
        XCTAssertEqual(map["Battery"], 29)
        // One of the CPU entries should map
        XCTAssertTrue(map.keys.contains { $0.hasPrefix("Efficiency Core") || $0.hasPrefix("Performance Core") })
    }

    func testSMCFanProviderReturnsRPMs() {
        let mock = MockSMC()
        let rpms = SMCFanProvider(smc: mock).fanRPMs()
        XCTAssertEqual(rpms ?? [], [0, 0])
    }
}
