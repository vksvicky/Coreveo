@testable import Coreveo
import XCTest

final class SensorAggregationTests: XCTestCase {
	func testAverageIgnoresNils() {
		XCTAssertEqual(SensorAggregator.average([1.0, nil, 3.0]), 2.0)
	}

	func testAverageAllNilReturnsNil() {
		XCTAssertNil(SensorAggregator.average([nil, nil]))
	}
}
