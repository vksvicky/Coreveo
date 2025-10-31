@testable import Coreveo
import XCTest

private final class MockIOReportReader: IOReportReading {
	let channels: [IOReportChannel]
	let values: [String: Double]

	init(channels: [IOReportChannel], values: [String: Double]) {
		self.channels = channels
		self.values = values
	}

	func listChannels() -> [IOReportChannel] { channels }

	func readValue(group: String, channel: String) -> Double? {
		values["\(group)::\(channel)"]
	}
}

final class IOReportAbstractionTests: XCTestCase {
	func testChannelDiscovery() {
		let mock = MockIOReportReader(
			channels: [
				IOReportChannel(group: "Thermal", name: "CPU Die", unit: "C"),
				IOReportChannel(group: "Thermal", name: "GPU Die", unit: "C")
			],
			values: [:]
		)
		let chans = mock.listChannels()
		XCTAssertEqual(chans.count, 2)
		XCTAssertEqual(chans.first?.group, "Thermal")
		XCTAssertEqual(chans.first?.name, "CPU Die")
	}

	func testReadValueByGroupAndChannel() {
		let mock = MockIOReportReader(
			channels: [IOReportChannel(group: "Thermal", name: "CPU Die", unit: "C")],
			values: ["Thermal::CPU Die": 62.5]
		)
		XCTAssertEqual(mock.readValue(group: "Thermal", channel: "CPU Die"), 62.5)
		XCTAssertNil(mock.readValue(group: "Thermal", channel: "GPU Die"))
	}
}
