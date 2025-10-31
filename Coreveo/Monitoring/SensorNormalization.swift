import Foundation

/// Applies normalization and calibration transforms to raw sensor values.
/// Supports scaling, offset, clamping, and exponential weighted moving average smoothing.
/// Provides static methods to apply transforms from the sensor catalog to raw sensor readings.
public struct SensorNormalizer {
	/// Apply a transform to a raw sensor value.
	/// - Parameters:
	///   - value: Raw input value.
	///   - transform: Optional transform configuration from the catalog.
	///   - previousSmoothed: Prior smoothed value when using EWMA; pass `nil` for first sample.
	/// - Returns: Transformed value and updated smoothed value (if smoothing enabled).
	static func apply(
		value: Double,
		transform: SensorDefinition.Transform?,
		previousSmoothed: Double?
	) -> (value: Double, smoothed: Double?) {
		guard let transform = transform else { return (value, previousSmoothed) }
		var transformedValue = value
		if let scale = transform.scale { transformedValue *= scale }
		if let offset = transform.offset { transformedValue += offset }
		if let min = transform.clampMin { transformedValue = max(min, transformedValue) }
		if let maxValue = transform.clampMax { transformedValue = min(maxValue, transformedValue) }
		if let alpha = transform.smoothing {
			let previous = previousSmoothed ?? transformedValue
			let smoothed = alpha * transformedValue + (1 - alpha) * previous
			return (smoothed, smoothed)
		}
		return (transformedValue, previousSmoothed)
	}
}
