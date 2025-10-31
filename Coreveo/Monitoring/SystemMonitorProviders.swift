import Foundation
import IOKit

// MARK: - SystemMonitor Private Providers
// Extracted from SystemMonitor.swift to reduce file and class body length

/// Catalog-backed provider that applies mappings from raw sensor sources
struct CatalogMappingProvider: TemperatureSensorsProviding {
    let device: DeviceProfile
    let catalog: SensorCatalog?
    let flags: SensorFeatureFlags
    let rawSource: TemperatureSensorsProviding
    
    func readTemperatureSensors() -> [String: Double]? {
        // Get raw sensor readings first
        guard let rawReadings = rawSource.readTemperatureSensors() else { return nil }
        
        // If no catalog, pass through raw
        guard let catalog = catalog,
              let model = SourceRouter.selectModel(from: catalog, for: device) else {
            return rawReadings
        }
        
        // Apply catalog mappings: friendly names + transforms
        var mapped: [String: Double] = [:]
        var processedRawKeys = Set<String>()
        
        for sensor in model.sensors {
            // Check feature flags
            if let group = sensor.groups.first, !flags.isEnabled(group: group) { continue }
            
            guard let foundValue = findSensorValue(sensor.source, in: rawReadings, processedKeys: &processedRawKeys) else {
                continue
            }
            
            let (normalized, _) = SensorNormalizer.apply(value: foundValue, transform: sensor.transform, previousSmoothed: nil)
            mapped[sensor.friendlyName] = normalized
        }
        
        return mapped.isEmpty ? nil : mapped
    }
    
    private func findSensorValue(
        _ source: SensorDefinition.Source,
        in rawReadings: [String: Double],
        processedKeys: inout Set<String>
    ) -> Double? {
        switch source {
        case let .ioHwSensor(name):
            let value = rawReadings[name]
            if value != nil { processedKeys.insert(name) }
            return value
        case let .smc(key):
            let value = rawReadings[key]
            if value != nil { processedKeys.insert(key) }
            return value
        case let .ioReport(_, channel):
            let value = rawReadings[channel]
            if value != nil { processedKeys.insert(channel) }
            return value
        case .derived:
            return nil
        }
    }
}

/// Merges multiple temperature sensor providers
struct LocalMergedProvider: TemperatureSensorsProviding {
    let providers: [TemperatureSensorsProviding]
    init(_ providers: [TemperatureSensorsProviding]) { self.providers = providers }
    func readTemperatureSensors() -> [String: Double]? {
        var result: [String: Double] = [:]
        for provider in providers {
            if let map = provider.readTemperatureSensors() {
                for (key, value) in map { result[key] = value }
            }
        }
        return result.isEmpty ? nil : result
    }
}

/// IOReport provider using powermetrics as fallback
struct LocalIOReportProvider: TemperatureSensorsProviding {
    func readTemperatureSensors() -> [String: Double]? {
        var result: [String: Double] = [:]
        
        // Strategy: On Apple Silicon, powermetrics effectively mirrors IOReport thermal channels
        // Use it as our IOReport-equivalent source
        if let text = runPowermetricsForIOReport() {
            let parsed = PowermetricsParser.parse(text)
            for (key, value) in parsed.metrics {
                // Use channel names that match IOReport conventions
                let channelName: String = {
                    switch key {
                    case "CPU Die":
                        return "CPU Die"
                    case "GPU Die":
                        return "GPU Die"
                    case "Processor Power":
                        return "Processor Power"
                    case "GPU Power":
                        return "GPU Power"
                    default:
                        return key
                    }
                }()
                result[channelName] = value
            }
            if !result.isEmpty {
                NSLog("[Coreveo] IOReport (via powermetrics): \(result.count) channels → \(Array(result.keys).sorted())")
            }
        }
        
        // Also try IORegistry for any thermal sensors exposed there
        if let thermalSensors = readThermalFromIORegistry() {
            for (key, value) in thermalSensors where result[key] == nil {
                result[key] = value
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    private func readThermalFromIORegistry() -> [String: Double]? {
        var result: [String: Double] = [:]
        
        // Look for thermal-related services in IORegistry
        let matching = IOServiceMatching("IOHWSensor")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer { IOObjectRelease(entry) }
            
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let unmanaged = props else {
                entry = IOIteratorNext(iterator)
                continue
            }
            
            let dict = unmanaged.takeRetainedValue() as NSDictionary
            let unit = (dict["unit"] as? String) ?? (dict["IOHWSensorUnit"] as? String) ?? ""
            guard let name = dict["name"] as? String,
                  unit.lowercased().contains("c"),
                  let rawValue = dict["current-value"] as? NSNumber else {
                entry = IOIteratorNext(iterator)
                continue
            }
            
            var value = rawValue.doubleValue
            if let scale = (dict["scaling-factor"] as? NSNumber)?.doubleValue, scale > 0 {
                value /= scale
            } else if value > 1_000 {
                value /= 256  // Common fixed-point format
            }
            
            if value >= 20.0 && value <= 150.0 {
                result[name] = value
            }
            
            entry = IOIteratorNext(iterator)
        }
        
        return result.isEmpty ? nil : result
    }
    
    private static var lastPowermetricsCall: Date?
    private static var lastErrorLog: Date?
    private static let powermetricsThrottleSeconds: TimeInterval = 5.0
    
    private func runPowermetricsForIOReport() -> String? {
        // Throttle powermetrics calls (requires root, so avoid spamming)
        let now = Date()
        if let last = Self.lastPowermetricsCall, now.timeIntervalSince(last) < Self.powermetricsThrottleSeconds {
            return nil
        }
        Self.lastPowermetricsCall = now
        
        let task = Process()
        task.launchPath = "/usr/bin/powermetrics"
        task.arguments = ["-n", "1", "--samplers", "thermal"]
        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr
        do { try task.run() } catch {
            NSLog("[Coreveo] IOReport: powermetrics failed to run - \(error.localizedDescription)")
            return nil
        }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = errorData.isEmpty ? "unknown" : (String(data: errorData, encoding: .utf8) ?? "non-UTF8")
            // Only log errors once per minute to avoid spam
            if Self.lastErrorLog == nil || (Self.lastErrorLog.map { now.timeIntervalSince($0) >= 60.0 } ?? true) {
                NSLog("[Coreveo] IOReport: powermetrics exited with status \(task.terminationStatus) - \(errorMsg.prefix(200))")
                Self.lastErrorLog = now
            }
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty, let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}

/// Powermetrics provider for temperature sensors
struct LocalPowermetricsProvider: TemperatureSensorsProviding {
    func readTemperatureSensors() -> [String: Double]? {
        guard let text = runOnce() else { return nil }
        let reading = PowermetricsParser.parse(text)
        return reading.metrics.isEmpty ? nil : reading.metrics
    }
    private static var lastPowermetricsCall: Date?
    private static let powermetricsThrottleSeconds: TimeInterval = 5.0
    
    private func runOnce() -> String? {
        // Throttle powermetrics calls (requires root)
        let now = Date()
        if let last = Self.lastPowermetricsCall, now.timeIntervalSince(last) < Self.powermetricsThrottleSeconds {
            return nil
        }
        Self.lastPowermetricsCall = now
        
        let task = Process()
        task.launchPath = "/usr/bin/powermetrics"
        task.arguments = ["-n", "1", "--samplers", "thermal"]
        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr
        do { try task.run() } catch { return nil }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty, let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}

/// Merges catalog-mapped sensors (friendly names + transforms) with raw unmapped sensors
struct LocalCatalogMergedProvider: TemperatureSensorsProviding {
    let catalog: TemperatureSensorsProviding
    let raw: TemperatureSensorsProviding
    
    func readTemperatureSensors() -> [String: Double]? {
        var result: [String: Double] = [:]
        
        // Start with catalog-mapped sensors (have friendly names)
        if let catalogMap = catalog.readTemperatureSensors() {
            for (key, value) in catalogMap { result[key] = value }
        }
        
        // Add raw sensors for any not in catalog (show unmapped sensors too)
        if let rawMap = raw.readTemperatureSensors() {
            for (key, value) in rawMap where result[key] == nil {
                result[key] = value
            }
        }
        
        return result.isEmpty ? nil : result
    }
}
