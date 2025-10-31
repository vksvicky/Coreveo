import Foundation

/// Temperature sensors provider backed by a SensorCatalog mapping.
struct CatalogBackedTemperatureSensorsProvider: TemperatureSensorsProviding {
	let smc: SMCClient
	let device: DeviceProfile
	let catalog: SensorCatalog?
	let flags: SensorFeatureFlags

	init(smc: SMCClient = SystemSMCClient(),
	     device: DeviceProfile,
	     catalog: SensorCatalog?,
	     flags: SensorFeatureFlags = SensorFeatureFlags()) {
		self.smc = smc
		self.device = device
		self.catalog = catalog
		self.flags = flags
	}

	func readTemperatureSensors() -> [String : Double]? {
		// Read all available raw temps once
		guard let raw = smc.readTemperaturesC() else { return nil }
		guard let catalog = catalog,
			  let model = SourceRouter.selectModel(from: catalog, for: device) else {
			// No catalog for this model -> pass through raw names
			return raw.isEmpty ? nil : raw
		}

		var result: [String: Double] = [:]
		for sensor in model.sensors {
			// Respect feature flags by first group if any
			if let group = sensor.groups.first, !flags.isEnabled(group: group) { continue }
			switch sensor.source {
			case let .ioHwSensor(name):
				if let v = raw[name] {
					let (val, _) = SensorNormalizer.apply(value: v, transform: sensor.transform, previousSmoothed: nil)
					result[sensor.friendlyName] = val
				}
			case let .smc(key):
				if let v = raw[key] {
					let (val, _) = SensorNormalizer.apply(value: v, transform: sensor.transform, previousSmoothed: nil)
					result[sensor.friendlyName] = val
				}
			case let .ioReport(group, channel):
				// Until SystemIOReportReader is implemented, try mapping via IOHWSensor fallback
				let alias = channel
				if let v = raw[alias] {
					let (val, _) = SensorNormalizer.apply(value: v, transform: sensor.transform, previousSmoothed: nil)
					result[sensor.friendlyName] = val
				}
			case .derived:
				continue
			}
		}
		return result.isEmpty ? nil : result
	}
}

/// Helper to build a device profile and load a local catalog (best-effort).
enum CatalogBackedProviderFactory {
	static func makeDefault() -> TemperatureSensorsProviding {
		let model = SystemInfoReader.getModelIdentifier() ?? "Mac"
		let os = ProcessInfo.processInfo.operatingSystemVersionString
		let isAppleSilicon = (SystemInfoReader.getCPUBrandString()?.contains("Apple") ?? true)
		let device = DeviceProfile(modelIdentifier: model, osVersion: parseOSVersion(os), isAppleSilicon: isAppleSilicon)
		let catalog = loadLocalCatalog()
		return CatalogBackedTemperatureSensorsProvider(device: device, catalog: catalog)
	}

	private static func parseOSVersion(_ s: String) -> String {
		// crude parse e.g., "Version 14.1 (Build ...)"
		let comps = s.split(separator: " ")
		for c in comps { if c.contains(".") { return String(c) } }
		return "14.0"
	}

	private static func loadLocalCatalog() -> SensorCatalog? {
		// Look for ~/Library/Application Support/Coreveo/sensor_catalog.json
		let fm = FileManager.default
		if let appSup = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
			let dir = appSup.appendingPathComponent("Coreveo", isDirectory: true)
			let url = dir.appendingPathComponent("sensor_catalog.json")
			if fm.fileExists(atPath: url.path) {
				if let data = try? Data(contentsOf: url), let cat = try? SensorCatalogLoader.load(from: data) { return cat }
			}
		}
		return nil
	}
}


