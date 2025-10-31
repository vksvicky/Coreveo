@testable import Coreveo
import XCTest

final class DeviceRoutingTests: XCTestCase {
	private func sampleCatalog() throws -> SensorCatalog {
		let json = """
		{
		  "schemaVersion": 1,
		  "models": [
		    {
		      "modelIdentifier": "Mac14,5",
		      "osMin": "14.0",
		      "osMax": "14.9",
		      "sensors": [
		        {"id": "cpu_temp_v14", "friendlyName": "CPU Temp", "unit": "celsius", "groups": ["CPU"], "source": {"type": "ioReport", "group": "Thermal", "channel": "CPU Die"}}
		      ]
		    },
		    {
		      "modelIdentifier": "Mac14,5",
		      "osMin": "15.0",
		      "sensors": [
		        {"id": "cpu_temp_v15", "friendlyName": "CPU Temp", "unit": "celsius", "groups": ["CPU"], "source": {"type": "ioReport", "group": "Thermal", "channel": "CPU Die"}}
		      ]
		    }
		  ]
		}
		"""
		return try SensorCatalogLoader.load(from: Data(json.utf8))
	}

	func testSelectsModelWithinOsRange() throws {
		let catalog = try sampleCatalog()
		let device = DeviceProfile(modelIdentifier: "Mac14,5", osVersion: "14.5", isAppleSilicon: true)
		let selected = SourceRouter.selectModel(from: catalog, for: device)
		XCTAssertNotNil(selected)
		XCTAssertEqual(selected?.osMax, "14.9")
	}

	func testPrefersHigherMinWhenBothMatch() throws {
		let catalog = try sampleCatalog()
		let device = DeviceProfile(modelIdentifier: "Mac14,5", osVersion: "15.1", isAppleSilicon: true)
		let selected = SourceRouter.selectModel(from: catalog, for: device)
		XCTAssertNotNil(selected)
		XCTAssertEqual(selected?.osMin, "15.0")
	}

	func testSourcePriorityAppleSilicon() {
		let r1 = SourceRouter.sourceRank(for: .ioReport(group: "Thermal", channel: "CPU"), isAppleSilicon: true)
		let r2 = SourceRouter.sourceRank(for: .ioHwSensor(name: "CPU Die"), isAppleSilicon: true)
		let r3 = SourceRouter.sourceRank(for: .smc(key: "TC0P"), isAppleSilicon: true)
		XCTAssertLessThan(r1, r2)
		XCTAssertLessThan(r2, r3)
	}

	func testSourcePriorityIntel() {
		let r1 = SourceRouter.sourceRank(for: .ioHwSensor(name: "CPU Die"), isAppleSilicon: false)
		let r2 = SourceRouter.sourceRank(for: .smc(key: "TC0P"), isAppleSilicon: false)
		let r3 = SourceRouter.sourceRank(for: .ioReport(group: "Thermal", channel: "CPU"), isAppleSilicon: false)
		XCTAssertLessThan(r1, r2)
		XCTAssertLessThan(r2, r3)
	}
}
