@testable import Coreveo
import XCTest

private final class MockSMCCoverage: SMCClient {
    func readTemperaturesC() -> [String: Double]? {
        var dict: [String: Double] = [:]
        // CPU Efficiency 1..4
        for index in 0...3 { dict[String(format: "TC%uE", index)] = 41 }
        // CPU Performance 1..12
        for index in 0...11 { dict[String(format: "TC%uP", index)] = (index % 2 == 0 ? 40 : 41) }
        // GPU clusters (six entries)
        for index in 0...5 { dict[String(format: "TG%uD", index)] = 41 }
        // Battery set
        dict["TB0T"] = 23
        dict["TB0G"] = 23
        dict["TB0B"] = 23
        dict["TB0P"] = 23
        // Airflow
        dict["TA0P"] = 34
        dict["TA1P"] = 35
        // Trackpad
        dict["TAPD"] = 24
        dict["TAPA"] = 22
        // Charger/Power
        dict["TPCD"] = 33
        dict["TP0P"] = 34
        // Thunderbolt L/R
        dict["TH0P"] = 26
        dict["TH1P"] = 25
        // Wireless
        dict["TW0P"] = 34
        // SSD
        dict["TS0P"] = 24
        dict["TS0S"] = 24
        return dict
    }
    func readFanRPMs() -> [Double]? { [1_200, 1_220] }
}

final class SMCMappingCoverageTests: XCTestCase {
    func testFriendlyNamesCoverExpectedSensors() {
        let provider = SMCTemperatureSensorsProvider(smc: MockSMCCoverage())
        guard let map = provider.readTemperatureSensors() else {
            XCTFail("No sensors returned from provider"); return
        }
        // CPU cores
        for index in 1...4 { XCTAssertNotNil(map["Efficiency Core \(index)"]) }
        for index in 1...12 { XCTAssertNotNil(map["Performance Core \(index)"]) }
        // GPU clusters (at least 6, indexed)
        XCTAssertNotNil(map["GPU Cluster"]) // first
        XCTAssertTrue(map.keys.contains(where: { $0.hasPrefix("GPU Cluster ") }))
        // Battery set
        XCTAssertNotNil(map["Battery"])
        XCTAssertNotNil(map["Battery Gas Gauge"])
        XCTAssertNotNil(map["Battery Management Unit"])
        XCTAssertNotNil(map["Battery Proximity"])
        // Airflow
        XCTAssertNotNil(map["Airflow Left"])
        XCTAssertNotNil(map["Airflow Right"])
        // Trackpad
        XCTAssertNotNil(map["Trackpad"])
        XCTAssertNotNil(map["Trackpad Actuator"])
        // Charger/Power
        XCTAssertNotNil(map["Charger Proximity"])
        XCTAssertNotNil(map["Power Supply Proximity"])
        // Thunderbolt
        XCTAssertNotNil(map["Left Thunderbolt Ports Proximity"])
        XCTAssertNotNil(map["Right Thunderbolt Ports Proximity"])
        // Wireless
        XCTAssertNotNil(map["Wireless Proximity"])
        // SSDs
        XCTAssertNotNil(map["SSD"])
        XCTAssertNotNil(map["SSD (NAND I/O)"])
    }
}
