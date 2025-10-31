@testable import Coreveo
import XCTest

final class SamplingSchedulerTests: XCTestCase {
	func testCoalescesConcurrentTicks() throws {
		let exp = expectation(description: "ticks")
		exp.expectedFulfillmentCount = 3
		let lock = NSLock()
		var inFlight = 0
		var ticks = 0
		let scheduler = SamplingScheduler(interval: 0.05, jitterFraction: 0.0, queue: .global(qos: .userInitiated)) {
			lock.lock(); inFlight += 1; lock.unlock()
			usleep(40_000) // 40ms work ~ close to interval; should coalesce some
			lock.lock()
			ticks += 1
			inFlight -= 1
			lock.unlock()
			exp.fulfill()
		}
		scheduler.start()
		wait(for: [exp], timeout: 1.0)
		scheduler.stop()
		XCTAssertGreaterThanOrEqual(ticks, 3)
	}

	func testValueCacheTTL() {
		let cache = ValueCache<Int>(ttl: 0.1)
		let now = Date()
		cache.set("a", value: 10, now: now)
		XCTAssertEqual(cache.get("a", now: now), 10)
		XCTAssertEqual(cache.get("a", now: now.addingTimeInterval(0.05)), 10)
		XCTAssertNil(cache.get("a", now: now.addingTimeInterval(0.11)))
	}
}
