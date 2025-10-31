import Foundation

/// Minimal device snapshot used for routing without touching system APIs (injectable for tests).
public struct DeviceProfile: Equatable {
	public let modelIdentifier: String   // e.g., "Mac14,5"
	public let osVersion: String         // e.g., "14.5"
	public let isAppleSilicon: Bool

	public init(modelIdentifier: String, osVersion: String, isAppleSilicon: Bool) {
		self.modelIdentifier = modelIdentifier
		self.osVersion = osVersion
		self.isAppleSilicon = isAppleSilicon
	}
}

/// Routing helpers for selecting model mappings and determining source priority.
public enum SourceRouter {
	/// Choose the best matching model catalog entry for the given device.
	static func selectModel(from catalog: SensorCatalog, for device: DeviceProfile) -> ModelCatalog? {
		let candidates = catalog.models.filter { $0.modelIdentifier == device.modelIdentifier }
		guard !candidates.isEmpty else { return nil }
		return candidates
			.filter { model in
				versionInRange(device.osVersion, min: model.osMin, max: model.osMax)
			}
			.sorted { lhs, rhs in
				// Prefer tighter upper bound, then higher min version.
				compareOptionalVersion(rhs.osMax, lhs.osMax) < 0 ||
				(compareOptionalVersion(rhs.osMax, lhs.osMax) == 0 && compareOptionalVersion(lhs.osMin, rhs.osMin) > 0)
			}
			.first
	}

	/// Return rank for a source on this device (lower is preferred).
	static func sourceRank(for source: SensorDefinition.Source, isAppleSilicon: Bool) -> Int {
		switch source {
		case .ioReport:
			return isAppleSilicon ? 0 : 2
		case .ioHwSensor:
			return isAppleSilicon ? 1 : 0
		case .smc:
			return isAppleSilicon ? 3 : 1
		case .derived:
			return 9
		}
	}

	/// Check if a version string v is within [min, max]. Missing bounds are open.
	static func versionInRange(_ v: String, min: String?, max: String?) -> Bool {
		if let min = min, compareVersion(v, min) < 0 { return false }
		if let max = max, compareVersion(v, max) > 0 { return false }
		return true
	}

	/// Compare two dotted version strings (returns -1, 0, 1).
	static func compareVersion(_ a: String, _ b: String) -> Int {
		let pa = a.split(separator: ".").compactMap { Int($0) }
		let pb = b.split(separator: ".").compactMap { Int($0) }
		let n = max(pa.count, pb.count)
		for i in 0..<n {
			let va = i < pa.count ? pa[i] : 0
			let vb = i < pb.count ? pb[i] : 0
			if va < vb { return -1 }
			if va > vb { return 1 }
		}
		return 0
	}

	/// Compare optional versions: nil is considered the loosest (sorted after concrete values).
	private static func compareOptionalVersion(_ a: String?, _ b: String?) -> Int {
		switch (a, b) {
		case let (sa?, sb?): return compareVersion(sa, sb)
		case (nil, nil): return 0
		case (nil, _): return 1
		case (_, nil): return -1
		}
	}
}


