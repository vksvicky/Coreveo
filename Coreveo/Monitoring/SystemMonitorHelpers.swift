import Foundation

// MARK: - SystemMonitor Helper Functions
// Extracted from SystemMonitor.swift to reduce class body length

/// Helper functions for SystemMonitor that don't need to be part of the class
enum SystemMonitorHelpers {
    static func makeCatalogProvider(rawSource: TemperatureSensorsProviding) -> TemperatureSensorsProviding {
        let model = sysctlString("hw.model") ?? "Mac"
        let osString = ProcessInfo.processInfo.operatingSystemVersionString
        let osVersion: String = {
            for part in osString.split(separator: " ") where part.contains(".") {
                return String(part)
            }
            return "14.0"
        }()
        let cpuBrand = sysctlString("machdep.cpu.brand_string") ?? "Apple"
        let isAppleSilicon = cpuBrand.contains("Apple")
        let device = DeviceProfile(modelIdentifier: model, osVersion: osVersion, isAppleSilicon: isAppleSilicon)
        let catalog = loadLocalCatalog()
        let flags = SensorFeatureFlags()
        return CatalogMappingProvider(device: device, catalog: catalog, flags: flags, rawSource: rawSource)
    }
    
    static func loadLocalCatalog() -> SensorCatalog? {
        let fm = FileManager.default
        
        // First, try user override in Application Support (takes precedence)
        if let appSup = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSup.appendingPathComponent("Coreveo", isDirectory: true)
            let url = dir.appendingPathComponent("sensor_catalog.json")
            if fm.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let catalog = try? SensorCatalogLoader.load(from: data) {
                NSLog("[Coreveo] Loaded sensor catalog from Application Support override: \(url.path)")
                return catalog
            }
        }
        
        // Fallback to bundled catalog in Resources
        if let bundleUrl = Bundle.main.url(forResource: "sensor_catalog", withExtension: "json"),
           let data = try? Data(contentsOf: bundleUrl),
           let catalog = try? SensorCatalogLoader.load(from: data) {
            NSLog("[Coreveo] Loaded sensor catalog from bundle: \(bundleUrl.path)")
            return catalog
        }
        
        NSLog("[Coreveo] No sensor catalog found - using raw sensors only")
        return nil
    }

    static func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        let res = sysctlbyname(name, &buf, &size, nil, 0)
        if res == 0 { return String(cString: buf) }
        return nil
    }
    
    static func isAppleSilicon() -> Bool {
        let brand = sysctlString("machdep.cpu.brand_string") ?? ""
        return brand.contains("Apple")
    }
}
