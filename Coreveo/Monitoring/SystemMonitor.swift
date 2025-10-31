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

// MARK: - SystemMonitor

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
        if SystemMonitorHelpers.isAppleSilicon() {
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
        let catalogProvider = SystemMonitorHelpers.makeCatalogProvider(rawSource: rawProvider)
        
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
