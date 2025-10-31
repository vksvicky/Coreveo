@testable import Coreveo
import XCTest

final class CoverageMetricsTests: XCTestCase {
	func testCounts() {
		let metrics = CoverageMetrics()
		metrics.increment("Thermal.CPU Die")
		metrics.increment("Thermal.CPU Die")
		metrics.increment("Thermal.GPU Die")
		let snapshot = metrics.snapshot()
		XCTAssertEqual(snapshot["Thermal.CPU Die"], 2)
		XCTAssertEqual(snapshot["Thermal.GPU Die"], 1)
	}
}
