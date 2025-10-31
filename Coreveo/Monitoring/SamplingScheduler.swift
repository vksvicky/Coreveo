import Foundation

/// Schedules periodic sampling with coalescing and simple jitter to avoid thundering herd.
final class SamplingScheduler {
	private let queue: DispatchQueue
	private var timer: DispatchSourceTimer?
	private(set) var interval: TimeInterval
	private let jitterFraction: Double
	private var isRunning = false
	private var pending = false
	private let handler: () -> Void

	init(interval: TimeInterval, jitterFraction: Double = 0.05, queue: DispatchQueue = .global(qos: .utility), handler: @escaping () -> Void) {
		self.interval = max(0.05, interval)
		self.jitterFraction = max(0.0, min(jitterFraction, 0.2))
		self.queue = queue
		self.handler = handler
	}

	func start() {
		guard !isRunning else { return }
		isRunning = true
		scheduleTimer()
	}

	func stop() {
		isRunning = false
		timer?.cancel()
		timer = nil
		pending = false
	}

	func updateInterval(_ newInterval: TimeInterval) {
		interval = max(0.05, newInterval)
		guard isRunning else { return }
		scheduleTimer()
	}

	private func scheduleTimer() {
		timer?.cancel()
		let t = DispatchSource.makeTimerSource(queue: queue)
		let base = interval
		let jitter = base * jitterFraction
		let due = DispatchTime.now() + base + Double.random(in: -jitter...jitter)
		t.schedule(deadline: due, repeating: base)
		t.setEventHandler { [weak self] in self?.tick() }
		t.resume()
		timer = t
	}

	private func tick() {
		if pending { return } // coalesce if previous tick still executing
		pending = true
		handler()
		pending = false
	}
}

/// Cache for latest sampled values with staleness control.
final class ValueCache<Value> {
	private struct Entry { let value: Value; let timestamp: Date }
	private var storage: [String: Entry] = [:]
	private let lock = NSLock()
	private let ttl: TimeInterval

	init(ttl: TimeInterval) { self.ttl = ttl }

	func set(_ key: String, value: Value, now: Date = Date()) {
		lock.lock(); defer { lock.unlock() }
		storage[key] = Entry(value: value, timestamp: now)
	}

	func get(_ key: String, now: Date = Date()) -> Value? {
		lock.lock(); defer { lock.unlock() }
		guard let e = storage[key] else { return nil }
		if now.timeIntervalSince(e.timestamp) > ttl { storage.removeValue(forKey: key); return nil }
		return e.value
	}

	func clear() {
		lock.lock(); defer { lock.unlock() }
		storage.removeAll()
	}
}


