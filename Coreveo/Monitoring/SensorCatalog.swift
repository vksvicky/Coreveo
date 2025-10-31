import Foundation

// MARK: - Sensor Catalog Schema (v1)

/// Versioned catalog describing sensors available per Mac model and OS range.
/// Maps sensor keys and channels to friendly names, units, and transformations
/// for specific Mac models and OS versions.
public struct SensorCatalog: Codable, Equatable {
	/// Schema version of this catalog.
	public let schemaVersion: Int
	/// Per‑model catalog entries.
	public let models: [ModelCatalog]
}

/// Per‑model catalog slice with OS bounds and sensor definitions.
/// Defines sensor mappings for a specific Mac model within a macOS version range.
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
/// Defines how to read a sensor, its display name, units, and any normalization needed.
public struct SensorDefinition: Codable, Equatable {
	/// Stable internal id (e.g., "cpu.e-core.1").
	public let id: String              // stable id, e.g., "cpu.e-core.1"
	/// User‑visible display name.
	public let friendlyName: String    // user-visible name
	/// Physical unit.
	public let unit: Unit
	/// Logical grouping tags (e.g., ["CPU", "Thermal"]).
	public let groups: [String]
	/// Source specification for reading this sensor.
	public let source: Source
	/// Optional calibration/normalization transform.
	public let transform: Transform?

	/// Supported sensor units.
	public enum Unit: String, Codable {
		case celsius
		case rpm
		case watt
		case percent
		case volt
		case amp
	}

	/// Source specification variants.
	public enum Source: Codable, Equatable {
		case ioReport(group: String, channel: String)
		case smc(key: String)
		case ioHwSensor(name: String)
		case derived(dependencies: [String], formula: String)

		// Custom Codable to handle nested enum
		private enum CodingKeys: String, CodingKey {
			case ioReport, smc, ioHwSensor, derived
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			if let ioReportDict = try? container.decode([String: String].self, forKey: .ioReport) {
				guard let group = ioReportDict["group"], let channel = ioReportDict["channel"] else {
					throw DecodingError.dataCorruptedError(
						forKey: .ioReport,
						in: container,
						debugDescription: "Missing group or channel"
					)
				}
				self = .ioReport(group: group, channel: channel)
			} else if let smcKey = try? container.decode(String.self, forKey: .smc) {
				self = .smc(key: smcKey)
			} else if let ioHwName = try? container.decode(String.self, forKey: .ioHwSensor) {
				self = .ioHwSensor(name: ioHwName)
			} else if let derivedDict = try? container.decode([String: [String]].self, forKey: .derived) {
				guard let deps = derivedDict["dependencies"], let formula = derivedDict["formula"]?.first else {
					throw DecodingError.dataCorruptedError(
						forKey: .derived,
						in: container,
						debugDescription: "Missing dependencies or formula"
					)
				}
				self = .derived(dependencies: deps, formula: formula)
			} else {
				throw DecodingError.dataCorruptedError(
					forKey: .ioReport,
					in: container,
					debugDescription: "Unknown source type"
				)
			}
		}

		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			switch self {
			case let .ioReport(group, channel):
				try container.encode(["group": group, "channel": channel], forKey: .ioReport)
			case let .smc(key):
				try container.encode(key, forKey: .smc)
			case let .ioHwSensor(name):
				try container.encode(name, forKey: .ioHwSensor)
			case let .derived(dependencies, formula):
				try container.encode(["dependencies": dependencies, "formula": [formula]], forKey: .derived)
			}
		}
	}

	/// Normalization/calibration transform configuration.
	public struct Transform: Codable, Equatable {
		/// Scale factor to multiply raw value.
		public let scale: Double?
		/// Offset to add after scaling.
		public let offset: Double?
		/// Clamp minimum value.
		public let clampMin: Double?
		/// Clamp maximum value.
		public let clampMax: Double?
		/// EWMA smoothing alpha (0.0 = no smoothing, 1.0 = ignore history).
		public let smoothing: Double?
	}
}

// MARK: - Loader and Validation

/// Loads and validates a `SensorCatalog` from JSON.
/// Provides static methods to decode sensor catalog JSON and validate its structure.
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
