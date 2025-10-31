import Foundation

enum CatalogBackedProviderFactory {
	static func makeDefault() -> TemperatureSensorsProviding {
		let model = SystemInfoReader.getModelIdentifier() ?? "Mac"
		let osString = ProcessInfo.processInfo.operatingSystemVersionString
		let osVersion = parseOSVersion(osString)
		let isAppleSilicon = (SystemInfoReader.getCPUBrandString()?.contains("Apple") ?? true)
		let device = DeviceProfile(modelIdentifier: model, osVersion: osVersion, isAppleSilicon: isAppleSilicon)
		let catalog = loadLocalCatalog()
		return CatalogBackedTemperatureSensorsProvider(device: device, catalog: catalog)
	}

	private static func parseOSVersion(_ s: String) -> String {
		for c in s.split(separator: " ") { if c.contains(".") { return String(c) } }
		return "14.0"
	}

    static func loadLocalCatalog() -> SensorCatalog? {
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


