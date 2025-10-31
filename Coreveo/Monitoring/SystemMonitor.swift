import AppKit
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import SystemConfiguration

// Note: temperature provider types live in TemperatureProvider.swift

/// Represents CPU tick counters for overall CPU usage calculation.
struct CPUTicks {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

/// Helper to read per-core CPU tick counters using host_processor_info.
enum PerCoreCPUReader {
    /// Reads per-core CPU tick counters.
    /// Returns an array per core: [user, system, idle, nice].
    static func readTicks() -> [[UInt64]]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = withUnsafeMutablePointer(to: &cpuCount) { cpuPtr in
            withUnsafeMutablePointer(to: &info) { infoPtr in
                withUnsafeMutablePointer(to: &infoCount) { countPtr in
                    host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, cpuPtr, infoPtr, countPtr)
                }
            }
        }
        guard result == KERN_SUCCESS, let infoUnwrapped = info else { return nil }

        let stride = MemoryLayout<processor_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        let data = UnsafeBufferPointer(start: infoUnwrapped, count: Int(infoCount))
        var perCore: [[UInt64]] = []
        perCore.reserveCapacity(Int(cpuCount))
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * stride
            let user = UInt64(data[base + Int(CPU_STATE_USER)])
            let system = UInt64(data[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(data[base + Int(CPU_STATE_IDLE)])
            let nice = UInt64(data[base + Int(CPU_STATE_NICE)])
            perCore.append([user, system, idle, nice])
        }

        // Deallocate returned memory
        let deallocSize = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: infoUnwrapped), deallocSize)
        return perCore
    }
}

/// Main system monitoring class that collects data from various macOS APIs.
///
/// This object owns a coalesced `DispatchSourceTimer` that periodically
/// samples system metrics on a utility queue and publishes them to the UI
/// on the main actor. Use `startMonitoring()` to begin sampling and
/// `stopMonitoring()` to halt sampling. You can change the sampling cadence
/// with `setUpdateInterval(seconds:)`.
@MainActor
class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()
    // Dependency: temperature provider
    nonisolated(unsafe) static var temperatureProvider: TemperatureProviding = CompositeTemperatureProvider()
    nonisolated(unsafe) static var temperatureSensorsProvider: TemperatureSensorsProviding = {
        // Build raw sensor sources
        let rawSources: [TemperatureSensorsProviding]
        if isAppleSilicon() {
            // On Apple Silicon: SMC has limited sensors, powermetrics requires root
            // So prioritize SMC (works without root) and make powermetrics optional
            rawSources = [
                SMCTemperatureSensorsProvider(),      // Primary: works without root
                LocalIOReportProvider(),              // Optional: requires root (will fail gracefully)
                LocalPowermetricsProvider(),          // Optional: requires root (will fail gracefully)
                SimulatedTemperatureSensorsProvider() // Fallback: ensures some sensors always visible
            ]
        } else {
            rawSources = [
                SMCTemperatureSensorsProvider(),       // Intel primary source
                LocalPowermetricsProvider(),          // Optional: requires root
                SimulatedTemperatureSensorsProvider()  // Fallback
            ]
        }
        
        // Build raw merged provider
        let rawProvider = LocalMergedProvider(rawSources)
        
        // Apply catalog mappings on top (catalog reads from raw and applies transforms)
        let catalogProvider = makeCatalogProvider(rawSource: rawProvider)
        
        // Merge: catalog applies friendly names/transforms, raw fills in unmapped sensors
        return LocalCatalogMergedProvider(catalog: catalogProvider, raw: rawProvider)
    }()
    nonisolated(unsafe) static var fanProvider: FanProviding = SMCFanProvider()

    // MARK: - Published Properties
    
    @Published var cpuUsage: Double = 25.0
    @Published var memoryUsage: Double = 45.0
    @Published var diskUsage: Double = 60.0
    @Published var networkUploadSpeed: Double = 5.2
    @Published var networkDownloadSpeed: Double = 12.8
    @Published var batteryLevel: Double = 85.0
    @Published var batteryHealth: String = "Good"
    @Published var temperature: Double = 45.0
    @Published var fanSpeeds: [Double] = [1_200.0, 1_220.0]
    @Published var temperatureSensors: [String: Double] = [:]
    @Published var perCoreUsage: [Double] = []
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var dispatchTimer: DispatchSourceTimer?
    private let monitoringQueue = DispatchQueue(label: "club.cycleruncode.coreveo.monitor", qos: .utility)
    private var updateIntervalSeconds: TimeInterval = 1.0
    private var lastNetworkStats: (bytesIn: UInt32, bytesOut: UInt32)?
    private var lastNetworkTime: Date?
    private var previousCoreTicks: [[UInt64]]?
    private var previousCPUTicks: CPUTicks?
    
    // MARK: - Public Methods
    
    private init() {
        // Initialize with default values
    }
    nonisolated private static func isAppleSilicon() -> Bool {
        let brand = sysctlString("machdep.cpu.brand_string") ?? ""
        return brand.contains("Apple")
    }

    // Catalog-backed provider that applies mappings from raw sensor sources
    private struct CatalogMappingProvider: TemperatureSensorsProviding {
        let device: DeviceProfile
        let catalog: SensorCatalog?
        let flags: SensorFeatureFlags
        let rawSource: TemperatureSensorsProviding
        
        func readTemperatureSensors() -> [String : Double]? {
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
                
                var foundValue: Double?
                switch sensor.source {
                case let .ioHwSensor(name):
                    foundValue = rawReadings[name]
                    if foundValue != nil { processedRawKeys.insert(name) }
                case let .smc(key):
                    foundValue = rawReadings[key]
                    if foundValue != nil { processedRawKeys.insert(key) }
                case let .ioReport(_, channel):
                    foundValue = rawReadings[channel]
                    if foundValue != nil { processedRawKeys.insert(channel) }
                case .derived:
                    continue
                }
                
                if let v = foundValue {
                    let (normalized, _) = SensorNormalizer.apply(value: v, transform: sensor.transform, previousSmoothed: nil)
                    mapped[sensor.friendlyName] = normalized
                }
            }
            
            return mapped.isEmpty ? nil : mapped
        }
    }

    nonisolated private static func makeCatalogProvider(rawSource: TemperatureSensorsProviding) -> TemperatureSensorsProviding {
        let model = sysctlString("hw.model") ?? "Mac"
        let osString = ProcessInfo.processInfo.operatingSystemVersionString
        let osVersion: String = {
            for part in osString.split(separator: " ") { if part.contains(".") { return String(part) } }
            return "14.0"
        }()
        let cpuBrand = sysctlString("machdep.cpu.brand_string") ?? "Apple"
        let isAppleSilicon = cpuBrand.contains("Apple")
        let device = DeviceProfile(modelIdentifier: model, osVersion: osVersion, isAppleSilicon: isAppleSilicon)
        let catalog = loadLocalCatalog()
        let flags = SensorFeatureFlags()
        return CatalogMappingProvider(device: device, catalog: catalog, flags: flags, rawSource: rawSource)
    }
    
    nonisolated private static func loadLocalCatalog() -> SensorCatalog? {
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

    nonisolated private static func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        let res = sysctlbyname(name, &buf, &size, nil, 0)
        if res == 0 { return String(cString: buf) }
        return nil
    }

    // MARK: - Local providers (to avoid cross-file symbol resolution issues)
    private struct LocalMergedProvider: TemperatureSensorsProviding {
        let providers: [TemperatureSensorsProviding]
        init(_ providers: [TemperatureSensorsProviding]) { self.providers = providers }
        func readTemperatureSensors() -> [String : Double]? {
            var result: [String: Double] = [:]
            for p in providers {
                if let map = p.readTemperatureSensors() {
                    for (k, v) in map { result[k] = v }
                }
            }
            return result.isEmpty ? nil : result
        }
    }

    private struct LocalIOReportProvider: TemperatureSensorsProviding {
        func readTemperatureSensors() -> [String : Double]? {
            var result: [String: Double] = [:]
            
            // Strategy: On Apple Silicon, powermetrics effectively mirrors IOReport thermal channels
            // Use it as our IOReport-equivalent source
            if let text = runPowermetricsForIOReport() {
                let parsed = PowermetricsParser.parse(text)
                for (k, v) in parsed.metrics {
                    // Use channel names that match IOReport conventions
                    let channelName: String = {
                        switch k {
                        case "CPU Die": return "CPU Die"
                        case "GPU Die": return "GPU Die"
                        case "Processor Power": return "Processor Power"
                        case "GPU Power": return "GPU Power"
                        default: return k
                        }
                    }()
                    result[channelName] = v
                }
                if !result.isEmpty {
                    NSLog("[Coreveo] IOReport (via powermetrics): \(result.count) channels → \(Array(result.keys).sorted())")
                }
            }
            
            // Also try IORegistry for any thermal sensors exposed there
            if let thermalSensors = readThermalFromIORegistry() {
                for (k, v) in thermalSensors {
                    if result[k] == nil { result[k] = v }
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
                } else if value > 1000 {
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
                if Self.lastErrorLog == nil || now.timeIntervalSince(Self.lastErrorLog!) >= 60.0 {
                    NSLog("[Coreveo] IOReport: powermetrics exited with status \(task.terminationStatus) - \(errorMsg.prefix(200))")
                    Self.lastErrorLog = now
                }
                return nil
            }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return nil }
            return s
        }
    }

    private struct LocalPowermetricsProvider: TemperatureSensorsProviding {
        func readTemperatureSensors() -> [String : Double]? {
            guard let text = runOnce() else { return nil }
            let r = PowermetricsParser.parse(text)
            return r.metrics.isEmpty ? nil : r.metrics
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
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return nil }
            return s
        }
    }
    
    // Merges catalog-mapped sensors (friendly names + transforms) with raw unmapped sensors
    private struct LocalCatalogMergedProvider: TemperatureSensorsProviding {
        let catalog: TemperatureSensorsProviding
        let raw: TemperatureSensorsProviding
        
        func readTemperatureSensors() -> [String : Double]? {
            var result: [String: Double] = [:]
            
            // Start with catalog-mapped sensors (have friendly names)
            if let catalogMap = catalog.readTemperatureSensors() {
                for (k, v) in catalogMap { result[k] = v }
            }
            
            // Add raw sensors for any not in catalog (show unmapped sensors too)
            if let rawMap = raw.readTemperatureSensors() {
                for (k, v) in rawMap {
                    // Only add if not already mapped by catalog
                    if result[k] == nil {
                        result[k] = v
                    }
                }
            }
            
            return result.isEmpty ? nil : result
        }
    }
    
    /// Begin periodic sampling of system metrics.
    func startMonitoring() {
        // Read stored interval if available
        let stored = UserDefaults.standard.double(forKey: "refreshIntervalSeconds")
        if stored > 0 { updateIntervalSeconds = stored }

        // Cancel any existing timer
        dispatchTimer?.cancel()
        dispatchTimer = nil

        // Create a coalesced dispatch timer on a utility queue
        let timer = DispatchSource.makeTimerSource(queue: monitoringQueue)
        timer.schedule(deadline: .now(), repeating: updateIntervalSeconds, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.updateSystemStats()
            }
        }
        dispatchTimer = timer
        timer.resume()

        // One immediate update for UI responsiveness
        Task { @MainActor in
            await updateSystemStats()
        }
    }
    
    /// Stop periodic sampling and release timer resources.
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        dispatchTimer?.cancel()
        dispatchTimer = nil
    }

    /// Update the monitoring interval at runtime (applies on next tick)
    /// Update the monitoring interval.
    /// - Parameter seconds: New sampling interval in seconds; must be > 0.
    func setUpdateInterval(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        updateIntervalSeconds = seconds
        // Re-schedule to apply immediately
        startMonitoring()
    }

    /// Manually refresh all metrics once. Useful for user-initiated refresh and tests.
    func refreshNow() async {
        await updateSystemStats()
    }
    
    // MARK: - Private Methods
    
    private func updateSystemStats() async {
        // Run all system API calls in parallel on background threads
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.updateCPUUsage() }
            group.addTask { await self.updateMemoryUsage() }
            group.addTask { await self.updateDiskUsage() }
            group.addTask { await self.updateNetworkStats() }
            group.addTask { await self.updateBatteryInfo() }
            group.addTask { await self.updateTemperature() }
            group.addTask { await self.updateFanSpeeds() }
            group.addTask { await self.updateTemperatureSensors() }
            group.addTask { await self.updatePerCoreUsage() }
        }
    }
    
    nonisolated private func updateCPUUsage() async {
        guard let current = SystemMetricsReader.readCPUTicks() else { return }
        
        let previous = await MainActor.run { previousCPUTicks }
        
        if let previous = previous {
            if let usage = SystemMetricsReader.calculateCPUUsage(previous: previous, current: current) {
                await MainActor.run {
                    cpuUsage = usage
                    previousCPUTicks = current
                }
            } else {
                // Zero delta: update ticks anyway for next cycle
                await MainActor.run {
                    previousCPUTicks = current
                }
            }
        } else {
            // First read: store ticks and initialize to 0
            await MainActor.run {
                cpuUsage = 0.0
                previousCPUTicks = current
            }
        }
    }

    nonisolated private func updatePerCoreUsage() async {
        guard let ticks = PerCoreCPUReader.readTicks() else { return }
        await applyPerCoreTicksSnapshot(ticks)
    }

    /// Compute and publish per-core usage from successive tick snapshots.
    /// This is designed for future wiring to real per-core tick sources.
    func applyPerCoreTicksSnapshot(_ current: [[UInt64]]) async {
        let previous = await MainActor.run { previousCoreTicks }
        if let previous = previous {
            let usage = CPUMetricsCalculator.computePerCoreUsage(previous: previous, current: current)
            await MainActor.run {
                perCoreUsage = usage
                previousCoreTicks = current
            }
        } else {
            // First read: initialize with zeros so UI shows core count immediately
            await MainActor.run {
                perCoreUsage = Array(repeating: 0.0, count: current.count)
                previousCoreTicks = current
            }
        }
    }
    
    nonisolated private func updateMemoryUsage() async {
        guard let usage = SystemMetricsReader.readMemoryUsage() else { return }
        await MainActor.run {
            memoryUsage = usage
        }
    }
    
    nonisolated private func updateDiskUsage() async {
        guard let usage = SystemMetricsReader.readDiskUsage() else { return }
        await MainActor.run {
            diskUsage = usage
        }
    }
    
    nonisolated private func updateNetworkStats() async {
        let interface = "en0" // Primary network interface
        
        guard let interfaceData = SystemInfoReader.getNetworkInterfaceData(interface: interface) else {
            return
        }
        
        let currentTime = Date()
        let bytesIn = interfaceData.bytesIn
        let bytesOut = interfaceData.bytesOut
        
        let (lastStats, lastTime) = await MainActor.run { (lastNetworkStats, lastNetworkTime) }
        
        if let lastStats = lastStats, let lastTime = lastTime {
            let previous = (bytesIn: lastStats.bytesIn, bytesOut: lastStats.bytesOut, time: lastTime)
            let current = (bytesIn: bytesIn, bytesOut: bytesOut, time: currentTime)
            let speeds = SystemMetricsReader.calculateNetworkSpeeds(previous: previous, current: current)
            
            await MainActor.run {
                networkDownloadSpeed = speeds.downloadSpeed
                networkUploadSpeed = speeds.uploadSpeed
                lastNetworkStats = (bytesIn: bytesIn, bytesOut: bytesOut)
                lastNetworkTime = currentTime
            }
        } else {
            await MainActor.run {
                lastNetworkStats = (bytesIn: bytesIn, bytesOut: bytesOut)
                lastNetworkTime = currentTime
            }
        }
    }
    
    nonisolated private func updateBatteryInfo() async {
        let info = SystemMetricsReader.readBatteryInfo()
        await MainActor.run {
            batteryLevel = info.level
            batteryHealth = info.health
        }
    }
    
    nonisolated private func updateTemperature() async {
        let currentCPU = await MainActor.run { cpuUsage }
        if let temp = SystemMonitor.temperatureProvider.cpuTemperatureC(currentCPUUsage: currentCPU) {
            await MainActor.run { temperature = temp }
        }
    }
    
    nonisolated private func updateFanSpeeds() async {
        // Derive fan speed from temperature (not CPU) to better match reality.
        if let rpms = SystemMonitor.fanProvider.fanRPMs() {
            await MainActor.run { fanSpeeds = rpms }
        }
    }

    nonisolated private func updateTemperatureSensors() async {
        if let map = SystemMonitor.temperatureSensorsProvider.readTemperatureSensors() {
            await MainActor.run { temperatureSensors = map }
        }
    }
}
