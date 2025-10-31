import Foundation
import IOKit
import IOKit.ps

// MARK: - SMC client abstraction

protocol SMCClient {
    func readTemperaturesC() -> [String: Double]? // key -> Celsius
    func readFanRPMs() -> [Double]?               // tachometers
}

struct SystemSMCClient: SMCClient {
    func readTemperaturesC() -> [String : Double]? {
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
        if !result.isEmpty {
            NSLog("[Coreveo] IOHWSensor discovered: \(result.count) temperature-like sensors → \(Array(result.keys).sorted())")
        }
        // Note: No sensors on Apple Silicon is expected - IOHWSensor primarily works on Intel Macs
        return result.isEmpty ? nil : result
    }

    private func readIOFans() -> [Double]? {
        var rpms: [Double] = []
        let matching = IOServiceMatching("IOFan")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if let props = copyProperties(entry) {
                if let rpm = props["actual-speed"] as? Double ?? props["current-speed"] as? Double ?? (props["actual-speed"] as? NSNumber)?.doubleValue ?? (props["current-speed"] as? NSNumber)?.doubleValue {
                    rpms.append(max(0, rpm))
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return rpms.isEmpty ? nil : rpms
    }

    private func registryName(_ entry: io_registry_entry_t) -> String? {
        var name: io_name_t = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
        if IORegistryEntryGetName(entry, &name) == KERN_SUCCESS {
            return withUnsafePointer(to: &name.0) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
        }
        return nil
    }

    private func copyProperties(_ entry: io_registry_entry_t) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let unmanaged = properties else { return nil }
        let dict = unmanaged.takeRetainedValue() as NSDictionary
        var result: [String: Any] = [:]
        for (k, v) in dict { if let key = k as? String { result[key] = v } }
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
            if raw > 1000 { return raw / 256 } // typical 8.8 or 16.8 formats
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
            if let v = readSMCFloat(conn, key: key) { readings[key] = v; return true }
            return false
        }
        // Adaptive discovery for CPU cores and GPU clusters without hard-coding counts.
        // Efficiency cores: TC{index}E; stop after a streak of misses once at least one hit found
        var foundAny = false
        var missStreak = 0
        var idx = 0
        while missStreak < 4 && idx < 64 { // safe upper bound
            let ok = tryRead(String(format: "TC%uE", idx))
            foundAny = foundAny || ok
            missStreak = ok ? 0 : (foundAny ? missStreak + 1 : 0)
            idx += 1
        }
        // Performance cores: TC{index}P/TC{index}C/TC{index}F variants
        foundAny = false; missStreak = 0; idx = 0
        while missStreak < 4 && idx < 64 {
            let ok = tryRead(String(format: "TC%uP", idx)) ||
                     tryRead(String(format: "TC%uC", idx)) ||
                     tryRead(String(format: "TC%uF", idx))
            foundAny = foundAny || ok
            missStreak = ok ? 0 : (foundAny ? missStreak + 1 : 0)
            idx += 1
        }
        // GPU clusters: TG{index}D
        foundAny = false; missStreak = 0; idx = 0
        while missStreak < 4 && idx < 32 {
            let ok = tryRead(String(format: "TG%uD", idx))
            foundAny = foundAny || ok
            missStreak = ok ? 0 : (foundAny ? missStreak + 1 : 0)
            idx += 1
        }
        // Common system sensors - probe multiple variants
        let commonKeys = [
            // Battery
            "TB0T", "TB1T", "TB2T", "TB0P", "TB1P", "TB0G", "TB0B",
            // SSD
            "TS0P", "TS1P", "TS2P", "TS0S", "TS1S",
            // Airflow
            "TA0P", "TA1P", "TA2P",
            // Wireless/Bluetooth
            "TW0P", "TW1P",
            // Power/Charger
            "TP0P", "TP1P", "TPCD",
            // Thunderbolt
            "TH0P", "TH1P", "TH2P", "TH3P",
            // Trackpad
            "TAPD", "TAPA",
            // Memory
            "TM0P", "TM1P",
            // Ambient
            "Tm0P", "Tm1P",
        ]
        for key in commonKeys { _ = tryRead(key) }
        
        // Probe numbered variants more aggressively
        for i in 0..<8 {
            _ = tryRead(String(format: "TC%uD", i)) // CPU die variants
            _ = tryRead(String(format: "TG%uP", i)) // GPU other variants
        }
        if !readings.isEmpty {
            NSLog("[Coreveo] SMC keys discovered: \(readings.count) → \(Array(readings.keys).sorted())")
        } else {
            NSLog("[Coreveo] SMC keys discovered none (AppleSMC not accessible?)")
        }
        return readings.isEmpty ? nil : readings
    }

    private func readSMCFanRPMs() -> [Double]? {
        guard let conn = openSMC() else { return nil }
        defer { IOServiceClose(conn) }
        var rpms: [Double] = []
        for i in 0...1 { // two fans typical
            let key = String(format: "F%uAc", i)
            if let rpm = readSMCFloat(conn, key: key) { rpms.append(rpm) }
        }
        return rpms.isEmpty ? nil : rpms
    }

    private func openSMC() -> io_connect_t? {
        let matching = IOServiceMatching("AppleSMC")
        var service: io_service_t = 0
        service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        var conn: io_connect_t = 0
        let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)
        return kr == KERN_SUCCESS ? conn : nil
    }

    // Minimal SMC read of float-like values (best-effort; returns nil on failure)
    private func readSMCFloat(_ conn: io_connect_t, key: String) -> Double? {
        // Best-effort SMC key read using IOConnectCallStructMethod. This avoids crashes by validating sizes and types.
        // If the platform disallows direct SMC access, we safely return nil.
        struct SMCKeyData_t {
            var key: UInt32 = 0
            var vers: UInt8 = 0, rVers: UInt8 = 0, major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0
            var eKey: UInt16 = 0
            var dataSize: UInt32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
            var bytes: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        }
        func fourCC(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) + UInt32($1) } }
        var input = SMCKeyData_t()
        input.key = fourCC(key)
        let inSize = MemoryLayout<SMCKeyData_t>.size
        var output = SMCKeyData_t()
        var outSize = MemoryLayout<SMCKeyData_t>.size
        // Method index for AppleSMC readKey is 5 on most systems; guard against failures.
        let kSMCReadIndex: UInt32 = 5
        let kr = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { outPtr in
                inPtr.withMemoryRebound(to: UInt8.self, capacity: inSize) { inBytes in
                    outPtr.withMemoryRebound(to: UInt8.self, capacity: outSize) { outBytes in
                        IOConnectCallStructMethod(conn, kSMCReadIndex, inBytes, inSize, outBytes, &outSize)
                    }
                }
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        // Interpret common fixed-point/float formats: SP78, FPE2
        let type = output.dataType
        let dt = String(format: "%c%c%c%c", (type>>24)&0xFF, (type>>16)&0xFF, (type>>8)&0xFF, type&0xFF)
        let bytesMirror = Mirror(reflecting: output.bytes).children.map { $0.value as! UInt8 }
        if dt == "SP78" {
            // Signed fixed point 7.8
            let msb = Int16(Int(bytesMirror[0]) << 8 | Int(bytesMirror[1]))
            return Double(msb) / 256.0
        } else if dt == "FPE2" {
            let raw = (UInt16(bytesMirror[0]) << 8) | UInt16(bytesMirror[1])
            return Double(raw) / 4.0
        } else if dt == "flt " {
            var v: UInt32 = 0
            for i in 0..<4 { v = (v << 8) | UInt32(bytesMirror[i]) }
            let f = Float(bitPattern: v)
            return Double(f)
        }
        return nil
    }
}

// MARK: - Providers backed by SMC

struct SMCTemperatureSensorsProvider: TemperatureSensorsProviding {
    let smc: SMCClient
    init(smc: SMCClient = SystemSMCClient()) { self.smc = smc }

    func readTemperatureSensors() -> [String : Double]? {
        guard let raw = smc.readTemperaturesC() else { return nil }
        var result: [String: Double] = [:]
        var counts: [String: Int] = [:]
        for (key, value) in raw {
            // Always show sensors - use friendly name if available, otherwise show SMC key
            let baseName = smcKeyToFriendlyName(key) ?? formatSMCKeyAsName(key)
            // Ensure uniqueness for repeated sensors (e.g., multiple GPU Cluster)
            if result[baseName] == nil {
                result[baseName] = value
                counts[baseName] = 1
            } else {
                let next = (counts[baseName] ?? 1) + 1
                counts[baseName] = next
                let unique = "\(baseName) \(next)"
                result[unique] = value
            }
        }
        return result.isEmpty ? nil : result
    }

    private func formatSMCKeyAsName(_ key: String) -> String {
        // Format unknown SMC keys into readable names (e.g., "TB0T" -> "Battery (TB0T)")
        if key.count >= 3 {
            let prefix = String(key.prefix(2))
            let domain: String = {
                switch prefix {
                case "TC": return "CPU"
                case "TG": return "GPU"
                case "TB": return "Battery"
                case "TS": return "SSD"
                case "TA": return "Airflow"
                case "TP": return "Power"
                case "TH": return "Thunderbolt"
                case "TW": return "Wireless"
                default: return "Sensor"
                }
            }()
            return "\(domain) (\(key))"
        }
        return key
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
        switch key {
            case "TG0D", "TG0P": return "GPU Cluster"
            case "TB0T": return "Battery"
            case "TA0P": return "Airflow Left"
            case "TA1P": return "Airflow Right"
            case "TS0P": return "SSD"
            case "TB0G": return "Battery Gas Gauge"
            case "TB0B": return "Battery Management Unit"
            case "TB0P": return "Battery Proximity"
            case "TAPD": return "Trackpad"
            case "TAPA": return "Trackpad Actuator"
            case "TPCD": return "Charger Proximity"
            case "TP0P": return "Power Supply Proximity"
            case "TH0P": return "Left Thunderbolt Ports Proximity"
            case "TH1P": return "Right Thunderbolt Ports Proximity"
            case "TW0P": return "Wireless Proximity"
            case "TS0S": return "SSD (NAND I/O)"
            default: return nil
        }
    }

    private func matchKey(_ key: String, patterns: [String: String]) -> (String, Int)? {
        for (pattern, prefix) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: key.utf16.count)
                if let m = regex.firstMatch(in: key, options: [], range: range), m.numberOfRanges >= 2,
                   let r = Range(m.range(at: 1), in: key), let idx = Int(key[r]) {
                    return (prefix, idx + 1) // SMC often 0-based; present 1-based
                }
            }
        }
        return nil
    }
}

protocol FanProviding {
    func fanRPMs() -> [Double]?
}

struct SMCFanProvider: FanProviding {
    let smc: SMCClient
    init(smc: SMCClient = SystemSMCClient()) { self.smc = smc }
    func fanRPMs() -> [Double]? { smc.readFanRPMs() }
}

struct CompositeTemperatureSensorsProvider: TemperatureSensorsProviding {
    let primary: TemperatureSensorsProviding
    let fallback: TemperatureSensorsProviding
    init(primary: TemperatureSensorsProviding = SMCTemperatureSensorsProvider(),
         fallback: TemperatureSensorsProviding = SimulatedTemperatureSensorsProvider()) {
        self.primary = primary
        self.fallback = fallback
    }
    func readTemperatureSensors() -> [String : Double]? {
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
            let t = (clamped - 45) / 45
            base = 600 + t * (2200 - 600)
        }
        return [max(0, base + Double.random(in: -40...40)),
                max(0, base + Double.random(in: -40...40))]
    }
}

struct CompositeFanProvider: FanProviding {
    let primary: FanProviding
    let fallback: FanProviding
    init(primary: FanProviding = SMCFanProvider(),
         fallback: FanProviding) {
        self.primary = primary
        self.fallback = fallback
    }
    func fanRPMs() -> [Double]? { primary.fanRPMs() ?? fallback.fanRPMs() }
}


