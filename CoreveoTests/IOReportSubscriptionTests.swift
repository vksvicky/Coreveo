@testable import Coreveo
import XCTest

private final class StubReader: IOReportReading {
	var values: [String: Double] = [:]
	func listChannels() -> [IOReportChannel] { [] }
	func readValue(group: String, channel: String) -> Double? { values["\(group)::\(channel)"] }
}

final class IOReportSubscriptionTests: XCTestCase {
	func testSubscriptionReceivesValues() {
		let reader = StubReader()
		reader.values["Thermal::CPU Die"] = 60.0
		let manager = IOReportSubscriptionManager(reader: reader, interval: 0.05)
		let exp = expectation(description: "update")
		var received: Double?
		manager.subscribe(group: "Thermal", channel: "CPU Die") { value in
			received = value
			exp.fulfill()
		}
		manager.start()
		wait(for: [exp], timeout: 1.0)
		manager.stop()
		XCTAssertEqual(received, 60.0)
	}
}
