@testable import Coreveo
import XCTest

final class SmartNvmeReaderTests: XCTestCase {
	func testMockReader() {
		let reader = MockSmartNvmeReader(temp: 48.0, life: 92.0)
		XCTAssertEqual(reader.readTemperatureC(), 48.0)
		XCTAssertEqual(reader.readLifePercent(), 92.0)
	}
}
