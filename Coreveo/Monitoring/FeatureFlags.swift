import Foundation

/// Feature flags per sensor group.
public final class SensorFeatureFlags {
	private var flags: [String: Bool]
	public init(defaultEnabled: Bool = true) { self.flags = [:]; self.defaultEnabled = defaultEnabled }
	private let defaultEnabled: Bool

	public func setEnabled(_ enabled: Bool, for group: String) { flags[group.lowercased()] = enabled }
	public func isEnabled(group: String) -> Bool { flags[group.lowercased()] ?? defaultEnabled }
}
