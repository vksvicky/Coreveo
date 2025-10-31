import Foundation

/// Quarantines unknown/unmapped sensors to avoid spamming UI; emits telemetry once per key within TTL.
final class SensorQuarantine {
	private let ttl: TimeInterval
	private var lastReported: [String: Date] = [:]
	private let lock = NSLock()
	private let logger: TelemetryLogging
	private let model: String
	private let os: String

	init(ttl: TimeInterval = 3600, logger: TelemetryLogging, model: String, os: String) {
		self.ttl = ttl
		self.logger = logger
		self.model = model
		self.os = os
	}

	func seenUnknown(group: String, channel: String, now: Date = Date()) {
		let key = "\(group)::\(channel)"
		lock.lock(); defer { lock.unlock() }
		let last = lastReported[key]
		if let last = last, now.timeIntervalSince(last) < ttl { return }
		lastReported[key] = now
		logger.record(.missingChannel(model: model, os: os, group: group, channel: channel))
	}
}


