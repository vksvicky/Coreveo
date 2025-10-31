import Foundation

/// Minimal SMART/NVMe reader abstraction (scaffold).
public protocol SmartNvmeReading {
	func readTemperatureC() -> Double?
	func readLifePercent() -> Double?
}

/// Mock implementation for tests.
public final class MockSmartNvmeReader: SmartNvmeReading {
	private let temp: Double?
	private let life: Double?
	public init(temp: Double?, life: Double?) { self.temp = temp; self.life = life }
	public func readTemperatureC() -> Double? { temp }
	public func readLifePercent() -> Double? { life }
}


