@testable import Coreveo
import XCTest

final class SensorQuarantineTests: XCTestCase {
	func testTelemetryOncePerTTL() {
		let logger = InMemoryTelemetryLogger()
		let quarantine = SensorQuarantine(logger: logger, model: "Mac14,5", os: "14.5", ttl: 0.1)
		let now = Date()
		quarantine.seenUnknown(group: "Thermal", channel: "Mystery", now: now)
		quarantine.seenUnknown(group: "Thermal", channel: "Mystery", now: now.addingTimeInterval(0.05))
		XCTAssertEqual(logger.events.count, 1)
		quarantine.seenUnknown(group: "Thermal", channel: "Mystery", now: now.addingTimeInterval(0.11))
		XCTAssertEqual(logger.events.count, 2)
	}
}
