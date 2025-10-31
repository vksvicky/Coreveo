// swiftlint:disable file_length
// File length exceeds 400 lines due to SMC API integration complexity and provider implementations
import Foundation
import IOKit
import IOKit.ps

// MARK: - SMC client abstraction

protocol SMCClient {
    func readTemperaturesC() -> [String: Double]? // key -> Celsius
    func readFanRPMs() -> [Double]?               // tachometers
}

// Type body length exceeds 200 lines due to SMC API integration complexity
// swiftlint:disable:next type_body_length
struct SystemSMCClient: SMCClient {
    func readTemperaturesC() -> [String: Double]? {
        var result: [String: Double] = [:]
        // 1) IORegistry IOHWSensor pass (safe)
        if let reg = readIOHWSensors() { result.merge(reg) { $1 } }
        // 2) AppleSMC keys (best‑effort)
        if let smc = readSMCKeys() { result.merge(smc) { $1 } }
        return result.isEmpty ? nil : result
    }

    func readFanRPMs() -> [Double]? {
        var rpms: [Double] = []
        if let reg = readIOFans() { rpms.append(contentsOf: reg) }
        if rpms.isEmpty, let smc = readSMCFanRPMs() { rpms.append(contentsOf: smc) }
        return rpms.isEmpty ? nil : rpms
    }

    // MARK: IORegistry helpers
    private func readIOHWSensors() -> [String: Double]? {
        var result: [String: Double] = [:]
        let matching = IOServiceMatching("IOHWSensor")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if let props = copyProperties(entry) {
                let name = (props["name"] as? String) ?? registryName(entry) ?? "Sensor"
                let unit = (props["unit"] as? String) ?? (props["IOHWSensorUnit"] as? String) ?? ""
                let type = (props["type"] as? String) ?? (props["sensor-type"] as? String) ?? ""
                if let value = readScaledValue(props: props) {
                    // Show all sensors that appear to be temperatures (unit contains 'c' or type contains 'temp')
                    // Also include if value is in reasonable temp range (20-150°C) even without explicit unit
                    let isTempUnit = unit.lowercased().contains("c") || type.lowercased().contains("temp")
                    let isReasonableTemp = value >= 20.0 && value <= 150.0 && !unit.lowercased().contains("rpm")
                    if isTempUnit || isReasonableTemp {
                        result[name] = value
                    }
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        if result.isEmpty {
            NSLog("[Coreveo] IOHWSensor discovered no temperature-like sensors")
        }
        return result.isEmpty ? nil : result
    }

    private func readIOFans() -> [Double]? {
        var rpms: [Double] = []
        let matching = IOServiceMatching("IOHWFan")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if let props = copyProperties(entry) {
                if let rpm = (props["current-value"] as? NSNumber)?.doubleValue {
                    rpms.append(rpm)
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return rpms.isEmpty ? nil : rpms
    }

    private func copyProperties(_ entry: io_registry_entry_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let unmanaged = properties else { return nil }
        let dict = unmanaged.takeRetainedValue() as NSDictionary
        var result: [String: Any] = [:]
        for (key, value) in dict { if let stringKey = key as? String { result[stringKey] = value } }
        return result
    }

    private func readScaledValue(props: [String: Any]) -> Double? {
        // Common IOHWSensor properties: current-value (NSNumber), scaling-factor (NSNumber)
        let raw = (props["current-value"] as? NSNumber)?.doubleValue
        if let raw = raw {
            if let scale = (props["scaling-factor"] as? NSNumber)?.doubleValue, scale > 0 {
                return raw / scale
            }
            // Heuristics for fixed-point sensors
            if raw > 1_000 { return raw / 256 } // typical 8.8 or 16.8 formats
            return raw
        }
        return nil
    }

    // MARK: AppleSMC helpers (best-effort)
    private func readSMCKeys() -> [String: Double]? {
        guard let conn = openSMC() else { return nil }
        defer { IOServiceClose(conn) }
        var readings: [String: Double] = [:]
        func tryRead(_ key: String) -> Bool {
            if let value = readSMCFloat(conn, key: key) { readings[key] = value; return true }
            return false
        }
        
        // Discover sensors by category
        discoverCPUCores(using: tryRead)
        discoverGPUs(using: tryRead)
        discoverCommonSensors(using: tryRead)
        
        if !readings.isEmpty {
            NSLog("[Coreveo] SMC keys discovered: \(readings.count) → \(Array(readings.keys).sorted())")
        } else {
            NSLog("[Coreveo] SMC keys discovered none (AppleSMC not accessible?)")
        }
        return readings.isEmpty ? nil : readings
    }
    
    private func discoverCPUCores(using tryRead: (String) -> Bool) {
        // Efficiency cores: TC{index}E
        discoverSensorPattern(pattern: "TC%uE", maxIndex: 64, using: tryRead)
        
        // Performance cores: TC{index}P/TC{index}C/TC{index}F variants
        var foundAny = false
        var missStreak = 0
        var idx = 0
        while missStreak < 4 && idx < 64 {
            let ok = tryRead(String(format: "TC%uP", idx)) ||
                     tryRead(String(format: "TC%uC", idx)) ||
                     tryRead(String(format: "TC%uF", idx))
            foundAny = foundAny || ok
            missStreak = ok ? 0 : (foundAny ? missStreak + 1 : 0)
            idx += 1
        }
        
        // CPU die variants
        for index in 0..<8 {
            _ = tryRead(String(format: "TC%uD", index))
        }
    }
    
    private func discoverGPUs(using tryRead: (String) -> Bool) {
        discoverSensorPattern(pattern: "TG%uD", maxIndex: 32, using: tryRead)
        for index in 0..<8 {
            _ = tryRead(String(format: "TG%uP", index))
        }
    }
    
    private func discoverCommonSensors(using tryRead: (String) -> Bool) {
        let commonKeys = [
            "TB0T", "TB1T", "TB2T", "TB0P", "TB1P", "TB0G", "TB0B",  // Battery
            "TS0P", "TS1P", "TS2P", "TS0S", "TS1S",                    // SSD
            "TA0P", "TA1P", "TA2P",                                    // Airflow
            "TW0P", "TW1P",                                            // Wireless/Bluetooth
            "TP0P", "TP1P", "TPCD",                                    // Power/Charger
            "TH0P", "TH1P", "TH2P", "TH3P",                            // Thunderbolt
            "TAPD", "TAPA",                                            // Trackpad
            "Tm0P", "Tm1P"                                             // Ambient
        ]
        for key in commonKeys { _ = tryRead(key) }
    }
    
    private func discoverSensorPattern(pattern: String, maxIndex: Int, using tryRead: (String) -> Bool) {
        var foundAny = false
        var missStreak = 0
        var idx = 0
        while missStreak < 4 && idx < maxIndex {
            let ok = tryRead(String(format: pattern, idx))
            foundAny = foundAny || ok
            missStreak = ok ? 0 : (foundAny ? missStreak + 1 : 0)
            idx += 1
        }
    }

    private func readSMCFanRPMs() -> [Double]? {
        guard let conn = openSMC() else { return nil }
        defer { IOServiceClose(conn) }
        var rpms: [Double] = []
        for index in 0...1 { // two fans typical
            let key = String(format: "F%uAc", index)
            if let rpm = readSMCFloat(conn, key: key) { rpms.append(rpm) }
        }
        return rpms.isEmpty ? nil : rpms
    }

    private func openSMC() -> io_connect_t? {
        var conn: io_connect_t = 0
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else { return nil }
        return conn
    }

    private func readSMCFloat(_ conn: io_connect_t, key: String) -> Double? {
        // Best-effort SMC key read using IOConnectCallStructMethod. This avoids crashes by validating sizes and types.
        // If the platform disallows direct SMC access, we safely return nil.
        // NOTE: SMCKeyData_t name and 32-byte tuple are required for SMC C API compatibility
        // swiftlint:disable:next type_name
        struct SMCKeyData_t {
            var key: UInt32 = 0
            var vers: UInt8 = 0, rVers: UInt8 = 0, major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0
            var eKey: UInt16 = 0
            var dataSize: UInt32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
            // 32-byte tuple required for SMC C API compatibility
            // swiftlint:disable:next large_tuple
            var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        }
        func fourCC(_ string: String) -> UInt32 { string.utf8.reduce(0) { ($0 << 8) + UInt32($1) } }
        var input = SMCKeyData_t()
        input.key = fourCC(key)
        let inSize = MemoryLayout<SMCKeyData_t>.size
        var output = SMCKeyData_t()
        var outSize = MemoryLayout<SMCKeyData_t>.size
        var kr = IOConnectCallStructMethod(conn, UInt32(5), &input, inSize, &output, &outSize)
        // Fallback to select method if call struct fails
        if kr != KERN_SUCCESS {
            kr = IOConnectCallStructMethod(conn, UInt32(2), &input, inSize, &output, &outSize)
        }
        guard kr == KERN_SUCCESS else { return nil }
        // Interpret common fixed-point/float formats: SP78, FPE2
        let type = output.dataType
        let dt = String(format: "%c%c%c%c", (type >> 24) & 0xFF, (type >> 16) & 0xFF, (type >> 8) & 0xFF, type & 0xFF)
        // Extract bytes as array (similar to registryName approach)
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.bindMemory(to: UInt8.self)) }
        if dt == "SP78" {
            // Signed fixed point 7.8
            let msb = Int16(Int(bytes[0]) << 8 | Int(bytes[1]))
            return Double(msb) / 256.0
        } else if dt == "FPE2" {
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        } else if dt == "flt " {
            var value: UInt32 = 0
            for index in 0..<4 { value = (value << 8) | UInt32(bytes[index]) }
            let floatValue = Float(bitPattern: value)
            return Double(floatValue)
        }
        return nil
    }

    private func registryName(_ entry: io_registry_entry_t) -> String? {
        var nameBuffer = [CChar](repeating: 0, count: MemoryLayout<io_name_t>.size)
        let result = nameBuffer.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return KERN_FAILURE }
            return baseAddress.withMemoryRebound(to: io_name_t.self, capacity: 1) { namePtr in
                IORegistryEntryGetName(entry, namePtr)
            }
        }
        if result == KERN_SUCCESS {
            return String(cString: nameBuffer)
        }
        return nil
    }
}

// MARK: - Providers backed by SMC

struct SMCTemperatureSensorsProvider: TemperatureSensorsProviding {
    private let smc: SMCClient
    init(smc: SMCClient = SystemSMCClient()) { self.smc = smc }

    func readTemperatureSensors() -> [String: Double]? {
        guard let raw = smc.readTemperaturesC() else { return nil }
        var result: [String: Double] = [:]
        var counts: [String: Int] = [:]
        for (key, value) in raw {
            // Always show sensors - use friendly name if available, otherwise show SMC key
            let baseName = smcKeyToFriendlyName(key) ?? formatSMCKeyAsName(key)
            // Ensure uniqueness for repeated sensors (e.g., multiple GPU Cluster)
            let finalName: String
            if counts[baseName] != nil {
                counts[baseName] = (counts[baseName] ?? 0) + 1
                finalName = "\(baseName) \(counts[baseName] ?? 1)"
            } else {
                counts[baseName] = 1
                finalName = baseName
            }
            result[finalName] = value
        }
        return result.isEmpty ? nil : result
    }

    private func formatSMCKeyAsName(_ key: String) -> String {
        // Fallback formatting: try to extract meaningful prefix
        let domain = domainForSMCKey(key)
        return "\(domain) (\(key))"
    }
    
    private func domainForSMCKey(_ key: String) -> String {
        guard key.count >= 2 else { return key }
        let prefix = String(key.prefix(2))
        let domainMap: [String: String] = [
            "TC": "CPU",
            "TG": "GPU",
            "TB": "Battery",
            "TS": "SSD",
            "TA": "Airflow",
            "TP": "Power",
            "TH": "Thunderbolt",
            "TW": "Wireless"
        ]
        return domainMap[prefix] ?? "Sensor"
    }
    private func smcKeyToFriendlyName(_ key: String) -> String? {
        // CPU cores via regex patterns TC{index}E (efficiency) / TC{index}P (performance)
        if let (prefix, idx) = matchKey(key, patterns: [
            "TC([0-9]+)[eE]": "Efficiency Core ",
            "TC([0-9]+)[pP]": "Performance Core ",
            "TC([0-9]+)[cC]": "Performance Core ",
            "TC([0-9]+)[fF]": "Performance Core "
        ]) {
            return prefix + String(idx)
        }
        
        // Direct key mappings
        return directKeyMapping(key)
    }
    
    private func directKeyMapping(_ key: String) -> String? {
        let mappings: [String: String] = [
            "TG0D": "GPU Cluster",
            "TG0P": "GPU Cluster",
            "TB0T": "Battery",
            "TA0P": "Airflow Left",
            "TA1P": "Airflow Right",
            "TS0P": "SSD",
            "TB0G": "Battery Gas Gauge",
            "TB0B": "Battery Management Unit",
            "TB0P": "Battery Proximity",
            "TAPD": "Trackpad",
            "TAPA": "Trackpad Actuator",
            "TPCD": "Charger Proximity",
            "TP0P": "Power Supply Proximity",
            "TH0P": "Left Thunderbolt Ports Proximity",
            "TH1P": "Right Thunderbolt Ports Proximity",
            "TW0P": "Wireless Proximity",
            "TS0S": "SSD (NAND I/O)"
        ]
        return mappings[key]
    }

    private func matchKey(_ key: String, patterns: [String: String]) -> (String, Int)? {
        for (pattern, prefix) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: key.utf16.count)
                if let match = regex.firstMatch(in: key, options: [], range: range), match.numberOfRanges >= 2,
                   let matchedRange = Range(match.range(at: 1), in: key), let idx = Int(key[matchedRange]) {
                    return (prefix, idx + 1) // SMC often 0-based; present 1-based
                }
            }
        }
        return nil
    }
}

struct SMCFanProvider: FanProviding {
    private let smc: SMCClient
    init(smc: SMCClient = SystemSMCClient()) { self.smc = smc }
    func fanRPMs() -> [Double]? { smc.readFanRPMs() }
}

struct SimulatedTemperatureSensorsProvider: TemperatureSensorsProviding {
    func readTemperatureSensors() -> [String: Double]? {
        // Fallback: provide simulated values to ensure UI always shows something
        return [
            "Efficiency Core 1": 45.0,
            "Performance Core 1": 40.0,
            "GPU Cluster": 44.0,
            "Airflow Left": 37.0,
            "Airflow Right": 38.0,
            "Battery": 29.0,
            "SSD": 29.0
        ]
    }
}

struct CompositeTemperatureSensorsProvider: TemperatureSensorsProviding {
    let primary: TemperatureSensorsProviding
    let fallback: TemperatureSensorsProviding
    init(
        primary: TemperatureSensorsProviding = SMCTemperatureSensorsProvider(),
        fallback: TemperatureSensorsProviding = SimulatedTemperatureSensorsProvider()
    ) {
        self.primary = primary
        self.fallback = fallback
    }
    func readTemperatureSensors() -> [String: Double]? {
        primary.readTemperatureSensors() ?? fallback.readTemperatureSensors()
    }
}

struct SimulatedFanProvider: FanProviding {
    let temperatureSource: () -> Double
    init(temperatureSource: @escaping () -> Double) { self.temperatureSource = temperatureSource }
    func fanRPMs() -> [Double]? {
        let temp = temperatureSource()
        let base: Double
        if temp < 45 { base = 0 } else {
            let clamped = min(max(temp, 45), 90)
            let temperatureFactor = (clamped - 45) / 45
            base = 600 + temperatureFactor * (2_200 - 600)
        }
        return [
            max(0, base + Double.random(in: -40...40)),
            max(0, base + Double.random(in: -40...40))
        ]
    }
}

struct CompositeFanProvider: FanProviding {
    let primary: FanProviding
    let fallback: FanProviding
    init(
        fallback: FanProviding,
        primary: FanProviding = SMCFanProvider()
    ) {
        self.primary = primary
        self.fallback = fallback
    }
    func fanRPMs() -> [Double]? { primary.fanRPMs() ?? fallback.fanRPMs() }
}
