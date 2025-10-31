@testable import Coreveo
import XCTest

final class FeatureFlagsTests: XCTestCase {
	func testEnableDisableGroups() {
		let flags = SensorFeatureFlags(defaultEnabled: true)
		XCTAssertTrue(flags.isEnabled(group: "Thermal"))
		flags.setEnabled(false, for: "Thermal")
		XCTAssertFalse(flags.isEnabled(group: "Thermal"))
		XCTAssertTrue(flags.isEnabled(group: "GPU"))
	}
}
