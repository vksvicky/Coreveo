import Foundation

/// Applies normalization/calibration transforms to raw sensor values.
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
		guard let t = transform else { return (value, previousSmoothed) }
		var v = value
		if let s = t.scale { v *= s }
		if let o = t.offset { v += o }
		if let min = t.clampMin { v = max(min, v) }
		if let maxv = t.clampMax { v = min(maxv, v) }
		if let alpha = t.smoothing {
			let prev = previousSmoothed ?? v
			let smooth = alpha * v + (1 - alpha) * prev
			return (smooth, smooth)
		}
		return (v, previousSmoothed)
	}
}


