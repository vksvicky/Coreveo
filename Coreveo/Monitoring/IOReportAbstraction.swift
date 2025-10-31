import Foundation

/// Feature flags for sensor infrastructure.
enum IOFeatures {
	static var ioreportEnabled: Bool { true }
}

/// A single IOReport-like channel description.
public struct IOReportChannel: Equatable {
	public let group: String
	public let name: String
	public let unit: String?

	public init(group: String, name: String, unit: String?) {
		self.group = group
		self.name = name
		self.unit = unit
	}
}

/// Minimal interface to enumerate and read IOReport channels.
protocol IOReportReading {
	func listChannels() -> [IOReportChannel]
	func readValue(group: String, channel: String) -> Double?
}

/// System-backed implementation (placeholder). On Apple Silicon, this would bridge to IOReport.
struct SystemIOReportReader: IOReportReading {
	func listChannels() -> [IOReportChannel] {
		guard IOFeatures.ioreportEnabled else { return [] }
		return [] // To be implemented with real IOReport enumeration.
	}

	func readValue(group: String, channel: String) -> Double? {
		guard IOFeatures.ioreportEnabled else { return nil }
		return nil // To be implemented with real IOReport read.
	}
}

/// Subscribes to IOReport groups and periodically samples requested channels with throttling.
final class IOReportSubscriptionManager {
	private let reader: IOReportReading
	private var scheduler: SamplingScheduler
	private var subscriptions: [String: [(channel: String, handler: (Double?) -> Void)]] = [:] // group -> handlers

	init(reader: IOReportReading, interval: TimeInterval = 0.5) {
		self.reader = reader
		// Initialize with empty handler; will be replaced in start()
		self.scheduler = SamplingScheduler(interval: interval, jitterFraction: 0.05, queue: .global(qos: .utility)) { }
	}

	func start() {
		scheduler.stop()
		// Create new scheduler with tick handler that captures self
		let manager = self
		let newSched = SamplingScheduler(interval: scheduler.interval, jitterFraction: 0.05, queue: .global(qos: .utility)) {
			manager.tick()
		}
		newSched.start()
		// Replace the scheduler
		scheduler = newSched
	}

	func stop() { scheduler.stop() }

	func subscribe(group: String, channel: String, handler: @escaping (Double?) -> Void) {
		subscriptions[group, default: []].append((channel: channel, handler: handler))
	}

	private func tick() {
		guard IOFeatures.ioreportEnabled else { return }
		for (group, subs) in subscriptions {
			for item in subs {
				let v = reader.readValue(group: group, channel: item.channel)
				item.handler(v)
			}
		}
	}
}


