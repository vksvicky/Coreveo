@testable import Coreveo
import XCTest

private final class MockHelperService: NSObject, HelperServiceProtocol {
	func readRestricted(_ request: HelperRequest, with reply: @escaping (HelperResponse) -> Void) {
		if request.kind == "smc" && request.identifier == "TC0P" {
			reply(HelperResponse(ok: true, value: 55.0, message: nil))
		} else {
			reply(HelperResponse(ok: false, value: nil, message: "not found"))
		}
	}
}

final class HelperXPCTests: XCTestCase {
	func testClientSuccessAndFailure() {
		let client = HelperClient(service: MockHelperService())
		let success = expectation(description: "success")
		let failure = expectation(description: "failure")

		client.readRestricted(kind: "smc", identifier: "TC0P") { result in
			if case let .success(value) = result { XCTAssertEqual(value, 55.0); success.fulfill() }
		}
		client.readRestricted(kind: "smc", identifier: "BAD") { result in
			if case let .failure(err) = result { XCTAssertFalse(err.localizedDescription.isEmpty); failure.fulfill() }
		}

		wait(for: [success, failure], timeout: 1.0)
	}

    func testHeartbeatLiveness() {
        let client = HelperClient(service: MockHelperService())
        XCTAssertFalse(client.isAlive())
        let now = Date()
        client.heartbeat(receivedAt: now)
        XCTAssertTrue(client.isAlive(now: now.addingTimeInterval(1)))
        XCTAssertFalse(client.isAlive(now: now.addingTimeInterval(10), timeout: 5))
    }
}
