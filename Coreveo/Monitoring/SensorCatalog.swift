import Foundation

// MARK: - Sensor Catalog Schema (v1)

/// Versioned catalog describing sensors available per Mac model and OS range.
public struct SensorCatalog: Codable, Equatable {
	/// Schema version of this catalog.
	public let schemaVersion: Int
	/// Per‑model catalog entries.
	public let models: [ModelCatalog]
}

/// Per‑model catalog slice with OS bounds and sensor definitions.
public struct ModelCatalog: Codable, Equatable {
	/// Model identifier (e.g., "Mac14,5") or SoC id (e.g., "t8112").
	public let modelIdentifier: String // e.g., "Mac14,5" or SoC id like "t8112"
	/// Minimum supported macOS version for this mapping.
	public let osMin: String?          // e.g., "14.0"
	/// Optional maximum macOS version for this mapping.
	public let osMax: String?          // optional upper bound
	/// Sensors available on this model.
	public let sensors: [SensorDefinition]
}

/// Declares a single sensor, its source, unit and optional transform.
public struct SensorDefinition: Codable, Equatable {
	/// Stable internal id (e.g., "cpu.e-core.1").
	public let id: String              // stable id, e.g., "cpu.e-core.1"
	/// User‑visible display name.
	public let friendlyName: String    // user-visible name
	/// Measurement unit.
	public let unit: Unit              // Celsius, RPM, Watt, etc.
	/// Group tags for UI organization.
	public let groups: [String]        // e.g., ["CPU", "Thermal"]
	/// Primary collection source.
	public let source: Source          // where/how to read
	/// Optional normalization and calibration.
	public let transform: Transform?   // normalization/calibration

	public enum Unit: String, Codable { case celsius, rpm, watt, percent, volt, amp }

	/// Where/how a sensor value is collected.
	public enum Source: Codable, Equatable {
		case ioReport(group: String, channel: String)
		case smc(key: String)
		case ioHwSensor(name: String)
		case derived(dependencies: [String], formula: String) // reserved for future

		private enum CodingKeys: String, CodingKey { case type, group, channel, key, name, dependencies, formula }
		private enum Kind: String, Codable { case ioReport, smc, ioHwSensor, derived }

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let kind = try container.decode(Kind.self, forKey: .type)
			switch kind {
			case .ioReport:
				self = .ioReport(
					group: try container.decode(String.self, forKey: .group),
					channel: try container.decode(String.self, forKey: .channel)
				)
			case .smc:
				self = .smc(key: try container.decode(String.self, forKey: .key))
			case .ioHwSensor:
				self = .ioHwSensor(name: try container.decode(String.self, forKey: .name))
			case .derived:
				self = .derived(
					dependencies: try container.decode([String].self, forKey: .dependencies),
					formula: try container.decode(String.self, forKey: .formula)
				)
			}
		}

		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			switch self {
			case let .ioReport(group, channel):
				try container.encode(Kind.ioReport, forKey: .type)
				try container.encode(group, forKey: .group)
				try container.encode(channel, forKey: .channel)
			case let .smc(key):
				try container.encode(Kind.smc, forKey: .type)
				try container.encode(key, forKey: .key)
			case let .ioHwSensor(name):
				try container.encode(Kind.ioHwSensor, forKey: .type)
				try container.encode(name, forKey: .name)
			case let .derived(dependencies, formula):
				try container.encode(Kind.derived, forKey: .type)
				try container.encode(dependencies, forKey: .dependencies)
				try container.encode(formula, forKey: .formula)
			}
		}
	}

	public struct Transform: Codable, Equatable {
		public let scale: Double?      // multiply
		public let offset: Double?     // add
		public let clampMin: Double?   // optional lower bound
		public let clampMax: Double?   // optional upper bound
		public let smoothing: Double?  // EWMA alpha (0..1)
	}
}

// MARK: - Loader and Validation

/// Loads and validates a `SensorCatalog` from JSON.
public enum SensorCatalogLoader {
	/// Decode and validate catalog from raw JSON data.
	public static func load(from jsonData: Data) throws -> SensorCatalog {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .useDefaultKeys
		let catalog = try decoder.decode(SensorCatalog.self, from: jsonData)
		try validate(catalog)
		return catalog
	}

	/// Validate catalog for schema compatibility and basic consistency.
	public static func validate(_ catalog: SensorCatalog) throws {
		guard catalog.schemaVersion == 1 else { throw ValidationError.unsupportedSchema }

		var seenIds = Set<String>()
		for model in catalog.models {
			guard !model.modelIdentifier.isEmpty else { throw ValidationError.invalidModelId }
			for sensor in model.sensors {
				guard !sensor.id.isEmpty, !sensor.friendlyName.isEmpty else { throw ValidationError.invalidSensor }
				let compositeId = model.modelIdentifier + "::" + sensor.id
				if seenIds.contains(compositeId) { throw ValidationError.duplicateSensorId }
				seenIds.insert(compositeId)
				// Basic unit sanity is implicit via enum
				// Optional: ensure transform ranges are sensible
				if let min = sensor.transform?.clampMin, let max = sensor.transform?.clampMax, min > max {
					throw ValidationError.invalidTransform
				}
				if let sm = sensor.transform?.smoothing, !(0.0...1.0).contains(sm) {
					throw ValidationError.invalidTransform
				}
			}
		}
	}

	/// Validation failures for `SensorCatalog`.
	public enum ValidationError: Error, LocalizedError {
		case unsupportedSchema
		case invalidModelId
		case invalidSensor
		case duplicateSensorId
		case invalidTransform

		public var errorDescription: String? {
			switch self {
			case .unsupportedSchema:
				return "Unsupported sensor catalog schema version"
			case .invalidModelId:
				return "Invalid or empty model identifier"
			case .invalidSensor:
				return "Invalid sensor definition"
			case .duplicateSensorId:
				return "Duplicate sensor id in catalog"
			case .invalidTransform:
				return "Invalid transform configuration"
			}
		}
	}
}

