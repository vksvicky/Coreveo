import AppKit
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import SystemConfiguration

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
    // MARK: - Published Properties
    
    @Published var cpuUsage: Double = 25.0
    @Published var memoryUsage: Double = 45.0
    @Published var diskUsage: Double = 60.0
    @Published var networkUploadSpeed: Double = 5.2
    @Published var networkDownloadSpeed: Double = 12.8
    @Published var batteryLevel: Double = 85.0
    @Published var batteryHealth: String = "Good"
    @Published var temperature: Double = 45.0
    @Published var fanSpeed: Double = 1_200.0
    @Published var perCoreUsage: [Double] = []
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var dispatchTimer: DispatchSourceTimer?
    private let monitoringQueue = DispatchQueue(label: "club.cycleruncode.coreveo.monitor", qos: .utility)
    private var updateIntervalSeconds: TimeInterval = 1.0
    private var lastNetworkStats: (bytesIn: UInt32, bytesOut: UInt32)?
    private var lastNetworkTime: Date?
    private var previousCoreTicks: [[UInt64]]?
    
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
            group.addTask { await self.updateFanSpeed() }
            group.addTask { await self.updatePerCoreUsage() }
        }
    }
    
    nonisolated private func updateCPUUsage() async {
        let host = mach_host_self()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info_data_t()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let user = Double(cpuLoadInfo.cpu_ticks.0)
            let system = Double(cpuLoadInfo.cpu_ticks.1)
            let idle = Double(cpuLoadInfo.cpu_ticks.2)
            let nice = Double(cpuLoadInfo.cpu_ticks.3)
            
            let total = user + system + idle + nice
            let usage = ((user + system + nice) / total) * 100.0
            
            await MainActor.run {
                cpuUsage = min(max(usage, 0), 100)
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
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let freeMemory = UInt64(vmStats.free_count) * UInt64(pageSize)
            let usedMemory = totalMemory - freeMemory
            
            let usage = (Double(usedMemory) / Double(totalMemory)) * 100.0
            await MainActor.run {
                memoryUsage = usage
            }
        }
    }
    
    nonisolated private func updateDiskUsage() async {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            if let totalSize = attributes[.systemSize] as? NSNumber,
               let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let usedSize = totalSize.uint64Value - freeSize.uint64Value
                let usage = (Double(usedSize) / Double(totalSize.uint64Value)) * 100.0
                await MainActor.run {
                    diskUsage = usage
                }
            }
        } catch {
            NSLog("Error getting disk usage: %@", error.localizedDescription)
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
        
        if let lastStats = lastStats,
           let lastTime = lastTime {
            let timeDiff = currentTime.timeIntervalSince(lastTime)
            let bytesInDiff = Int64(bytesIn) - Int64(lastStats.bytesIn)
            let bytesOutDiff = Int64(bytesOut) - Int64(lastStats.bytesOut)
            
            // Convert to bytes per second, then to Mbps
            let downloadSpeed = Double(bytesInDiff) / timeDiff / 1_000_000 * 8
            let uploadSpeed = Double(bytesOutDiff) / timeDiff / 1_000_000 * 8
            
            await MainActor.run {
                networkDownloadSpeed = downloadSpeed
                networkUploadSpeed = uploadSpeed
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
        // Simplified battery monitoring to avoid Core Foundation memory issues
        // For now, we'll disable battery monitoring to prevent crashes
        // This can be re-implemented later with proper memory management
        
        // Check if we're on a MacBook (has battery)
        let model = SystemInfoReader.getMacModel()
        if model.contains("MacBook") {
            // Simulate battery level for MacBooks
            await MainActor.run {
                batteryLevel = 85.0 // Simulated battery level
                batteryHealth = "Good"
            }
        } else {
            // Desktop Mac - no battery
            await MainActor.run {
                batteryLevel = 0
                batteryHealth = "N/A"
            }
        }
    }
    
    nonisolated private func updateTemperature() async {
        // Simplified temperature reading based on CPU usage
        // In a real implementation, you'd use IOKit to read from thermal sensors
        // For now, we'll simulate temperature based on CPU usage
        let currentCPU = await MainActor.run { cpuUsage }
        let temp = 30.0 + (currentCPU * 0.5) // Base temp + CPU load factor
        await MainActor.run {
            temperature = temp
        }
    }
    
    nonisolated private func updateFanSpeed() async {
        // This would require more complex IOKit calls to read fan speeds
        // For now, we'll simulate based on CPU usage
        let currentCPU = await MainActor.run { cpuUsage }
        let speed = currentCPU * 50.0 // RPM proportional to CPU usage
        await MainActor.run {
            fanSpeed = speed
        }
    }
}
