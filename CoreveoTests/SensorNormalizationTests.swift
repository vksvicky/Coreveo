@testable import Coreveo
import XCTest

final class SensorNormalizationTests: XCTestCase {
	func testScaleOffsetClamp() {
		let transform = SensorDefinition.Transform(
			scale: 2.0,
			offset: -1.0,
			clampMin: 0.0,
			clampMax: 10.0,
			smoothing: nil
		)
		let out = SensorNormalizer.apply(value: 3.0, transform: transform, previousSmoothed: nil)
		XCTAssertEqual(out.value, 5.0) // 3*2-1=5 within clamp
		XCTAssertNil(out.smoothed)
	}

	func testClampLower() {
		let transform = SensorDefinition.Transform(scale: 1.0, offset: 0.0, clampMin: 4.0, clampMax: nil, smoothing: nil)
		let out = SensorNormalizer.apply(value: 2.0, transform: transform, previousSmoothed: nil)
		XCTAssertEqual(out.value, 4.0)
	}

	func testClampUpper() {
		let transform = SensorDefinition.Transform(scale: 1.0, offset: 0.0, clampMin: nil, clampMax: 5.0, smoothing: nil)
		let out = SensorNormalizer.apply(value: 9.0, transform: transform, previousSmoothed: nil)
		XCTAssertEqual(out.value, 5.0)
	}

	func testSmoothingUsesPreviousWhenProvided() {
		let transform = SensorDefinition.Transform(scale: nil, offset: nil, clampMin: nil, clampMax: nil, smoothing: 0.5)
		let out = SensorNormalizer.apply(value: 10.0, transform: transform, previousSmoothed: 6.0)
		XCTAssertEqual(out.value, 8.0, accuracy: 1e-9) // 0.5*10 + 0.5*6
		XCTAssertNotNil(out.smoothed)
		guard let smoothed = out.smoothed else {
			XCTFail("Expected smoothed value")
			return
		}
		XCTAssertEqual(smoothed, 8.0, accuracy: 1e-9)
	}

	func testSmoothingFallsBackToSelfOnFirstSample() {
		let transform = SensorDefinition.Transform(scale: nil, offset: nil, clampMin: nil, clampMax: nil, smoothing: 0.3)
		let out = SensorNormalizer.apply(value: 7.0, transform: transform, previousSmoothed: nil)
		XCTAssertEqual(out.value, 7.0, accuracy: 1e-9)
		XCTAssertNotNil(out.smoothed)
		guard let smoothed = out.smoothed else {
			XCTFail("Expected smoothed value")
			return
		}
		XCTAssertEqual(smoothed, 7.0, accuracy: 1e-9)
	}
}
