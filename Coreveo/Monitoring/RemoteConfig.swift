import Foundation

/// Simple remote-config style loader for the sensor catalog, starting with local file override.
public enum SensorCatalogConfigLoader {
	/// Load catalog from a local file URL (e.g., user-provided override).
	public static func loadLocal(url: URL) throws -> SensorCatalog {
		let data = try Data(contentsOf: url, options: [.mappedIfSafe])
		return try SensorCatalogLoader.load(from: data)
	}
}


