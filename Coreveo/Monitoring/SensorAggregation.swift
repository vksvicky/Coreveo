import Foundation

/// Aggregation helpers for combining multiple sensor values into one logical reading.
enum SensorAggregator {
	/// Average the provided values, ignoring nils; returns nil if all are nil.
	static func average(_ values: [Double?]) -> Double? {
		let present = values.compactMap { $0 }
		guard !present.isEmpty else { return nil }
		let sum = present.reduce(0, +)
		return sum / Double(present.count)
	}
}
