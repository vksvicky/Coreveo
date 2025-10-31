@testable import Coreveo
import XCTest

final class PowermetricsParserTests: XCTestCase {
	func testParsesCpuGpuTempsAndPower() {
		let sample = """
		***** Sampled system activity (as ran by powermetrics) *****
		CPU die temperature: 65.3 C
		GPU die temperature: 52.1 C
		Processor Power: 7.50 W
		GPU Power: 3.21 W
		"""
		let reading = PowermetricsParser.parse(sample)
		XCTAssertEqual(reading.metrics["CPU Die"], 65.3)
		XCTAssertEqual(reading.metrics["GPU Die"], 52.1)
		XCTAssertEqual(reading.metrics["Processor Power"], 7.5)
		XCTAssertEqual(reading.metrics["GPU Power"], 3.21)
	}

	func testMissingFieldsAreIgnored() {
		let sample = """
		CPU die temperature: 70.0 C
		"""
		let reading = PowermetricsParser.parse(sample)
		XCTAssertEqual(reading.metrics["CPU Die"], 70.0)
		XCTAssertNil(reading.metrics["GPU Die"])
		XCTAssertNil(reading.metrics["Processor Power"])
	}
}
