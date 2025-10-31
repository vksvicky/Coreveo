@testable import Coreveo
import XCTest

final class SensorCatalogTests: XCTestCase {
	func testDecodeAndValidateMinimalCatalog() throws {
		let json = """
		{
		  "schemaVersion": 1,
		  "models": [
		    {
		      "modelIdentifier": "Mac14,5",
		      "osMin": "14.0",
		      "sensors": [
		        {
		          "id": "cpu.e-core.1",
		          "friendlyName": "Efficiency Core 1",
		          "unit": "celsius",
		          "groups": ["CPU", "Thermal"],
		          "source": { "type": "smc", "key": "TC0E" },
		          "transform": { "scale": 1.0 }
		        },
		        {
		          "id": "gpu.cluster",
		          "friendlyName": "GPU Cluster",
		          "unit": "celsius",
		          "groups": ["GPU", "Thermal"],
		          "source": { "type": "ioReport", "group": "Thermal", "channel": "GPU Die" }
		        }
		      ]
		    }
		  ]
		}
		"""
		let data = Data(json.utf8)
		let catalog = try SensorCatalogLoader.load(from: data)
		XCTAssertEqual(catalog.schemaVersion, 1)
		XCTAssertEqual(catalog.models.count, 1)
		XCTAssertEqual(catalog.models.first?.sensors.count, 2)
	}

	func testDuplicateIdsAcrossSameModelFails() throws {
		let json = """
		{
		  "schemaVersion": 1,
		  "models": [
		    {
		      "modelIdentifier": "Mac14,5",
		      "sensors": [
		        {"id": "x", "friendlyName": "A", "unit": "celsius", "groups": ["t"], "source": {"type": "smc", "key": "TC0E"}},
		        {"id": "x", "friendlyName": "B", "unit": "celsius", "groups": ["t"], "source": {"type": "smc", "key": "TC1E"}}
		      ]
		    }
		  ]
		}
		"""
		let data = Data(json.utf8)
		XCTAssertThrowsError(try SensorCatalogLoader.load(from: data)) { error in
			guard case SensorCatalogLoader.ValidationError.duplicateSensorId = error else {
				return XCTFail("Unexpected error: \(error)")
			}
		}
	}

	func testInvalidTransformRangeFails() throws {
		let json = """
		{
		  "schemaVersion": 1,
		  "models": [
		    {
		      "modelIdentifier": "Mac14,5",
		      "sensors": [
		        {"id": "x", "friendlyName": "A", "unit": "celsius", "groups": ["t"], "source": {"type": "smc", "key": "TC0E"}, "transform": {"clampMin": 100, "clampMax": 10}}
		      ]
		    }
		  ]
		}
		"""
		let data = Data(json.utf8)
		XCTAssertThrowsError(try SensorCatalogLoader.load(from: data)) { error in
			guard case SensorCatalogLoader.ValidationError.invalidTransform = error else {
				return XCTFail("Unexpected error: \(error)")
			}
		}
	}
}
