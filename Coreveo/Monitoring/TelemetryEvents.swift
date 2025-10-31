import Foundation

/// Structured telemetry events for sensor mapping issues and anomalies.
/// Used to track missing channels, renamed sensors, and value anomalies for catalog maintenance.
public enum TelemetryEvent: Equatable {
	case missingChannel(model: String, os: String, group: String, channel: String)
	case renamedChannel(model: String, os: String, from: String, to: String)
	case valueAnomaly(sensorId: String, observed: Double, reason: String)
}

/// Minimal logger protocol to allow swapping implementations and testing.
/// Provides a simple interface for recording telemetry events.
public protocol TelemetryLogging {
	func record(_ event: TelemetryEvent)
}

/// In-memory telemetry sink for tests and local development.
public final class InMemoryTelemetryLogger: TelemetryLogging {
	private(set) var events: [TelemetryEvent] = []
	private let lock = NSLock()

	public init() {}

	public func record(_ event: TelemetryEvent) {
		lock.lock(); defer { lock.unlock() }
		events.append(event)
	}
}
