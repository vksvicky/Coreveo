import Foundation

/// In-memory coverage metrics for sensor presence; no networking.
public final class CoverageMetrics {
	private var counters: [String: Int] = [:]
	private let lock = NSLock()

	public init() {}

	public func increment(_ key: String) {
		lock.lock(); defer { lock.unlock() }
		counters[key, default: 0] += 1
	}

	public func snapshot() -> [String: Int] {
		lock.lock(); defer { lock.unlock() }
		return counters
	}
}


