@testable import Coreveo
import XCTest

final class TelemetryEventsTests: XCTestCase {
	func testRecordMissingChannel() {
		let logger = InMemoryTelemetryLogger()
		logger.record(.missingChannel(model: "Mac14,5", os: "14.5", group: "Thermal", channel: "CPU Die"))
		XCTAssertEqual(logger.events.count, 1)
		guard let first = logger.events.first,
		      case let .missingChannel(model, os, group, channel) = first else {
			return XCTFail("wrong event")
		}
		XCTAssertEqual(model, "Mac14,5")
		XCTAssertEqual(os, "14.5")
		XCTAssertEqual(group, "Thermal")
		XCTAssertEqual(channel, "CPU Die")
	}

	func testRecordRenamedChannel() {
		let logger = InMemoryTelemetryLogger()
		logger.record(.renamedChannel(model: "Mac14,5", os: "15.0", from: "CPU Die", to: "CPU SoC"))
		guard let first = logger.events.first,
		      case let .renamedChannel(_, _, from, to) = first else {
			return XCTFail("wrong event")
		}
		XCTAssertEqual(from, "CPU Die")
		XCTAssertEqual(to, "CPU SoC")
	}

	func testRecordValueAnomaly() {
		let logger = InMemoryTelemetryLogger()
		logger.record(.valueAnomaly(sensorId: "cpu.e-core.1", observed: -20, reason: "below absolute zero"))
		guard let first = logger.events.first,
		      case let .valueAnomaly(id, observed, reason) = first else {
			return XCTFail("wrong event")
		}
		XCTAssertEqual(id, "cpu.e-core.1")
		XCTAssertEqual(observed, -20)
		XCTAssertEqual(reason, "below absolute zero")
	}
}
