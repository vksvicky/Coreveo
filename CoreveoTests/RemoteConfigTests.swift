@testable import Coreveo
import XCTest

final class RemoteConfigTests: XCTestCase {
	func testLoadLocalCatalog() throws {
		let json = """
		{
		  "schemaVersion": 1,
		  "models": [
		    {
		      "modelIdentifier": "Mac14,5",
		      "sensors": [
		        {"id": "x", "friendlyName": "CPU", "unit": "celsius", "groups": ["CPU"], "source": {"smc": "TC0P"}}
		      ]
		    }
		  ]
		}
		"""
		let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("catalog.json")
		try json.write(to: tmp, atomically: true, encoding: .utf8)
		let cat = try SensorCatalogConfigLoader.loadLocal(url: tmp)
		XCTAssertEqual(cat.models.count, 1)
		XCTAssertEqual(cat.models.first?.sensors.first?.friendlyName, "CPU")
	}
}
