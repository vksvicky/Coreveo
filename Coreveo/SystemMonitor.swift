import AppKit
import Foundation
import IOKit
import IOKit.pwr_mgt
import IOKit.ps
import SystemConfiguration

/// Main system monitoring class that collects data from various macOS APIs
@MainActor
public class SystemMonitor: ObservableObject {
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
    @Published var fanSpeed: Double = 1200.0
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var lastNetworkStats: (bytesIn: UInt32, bytesOut: UInt32)?
    private var lastNetworkTime: Date?
    
    // MARK: - Public Methods
    
    private init() {
        // Initialize with default values
    }
    
    public func startMonitoring() {
        // Start monitoring with 1-second intervals
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.updateSystemStats()
            }
        }
        
        // Initial update
        Task { @MainActor in
            await updateSystemStats()
        }
    }
    
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func updateSystemStats() async {
        await updateCPUUsage()
        await updateMemoryUsage()
        await updateDiskUsage()
        await updateNetworkStats()
        await updateBatteryInfo()
        await updateTemperature()
        await updateFanSpeed()
    }
    
    private func updateCPUUsage() async {
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
            
            cpuUsage = min(max(usage, 0), 100)
        }
    }
    
    private func updateMemoryUsage() async {
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
            
            memoryUsage = (Double(usedMemory) / Double(totalMemory)) * 100.0
        }
    }
    
    private func updateDiskUsage() async {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            if let totalSize = attributes[.systemSize] as? NSNumber,
               let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let usedSize = totalSize.uint64Value - freeSize.uint64Value
                diskUsage = (Double(usedSize) / Double(totalSize.uint64Value)) * 100.0
            }
        } catch {
            NSLog("Error getting disk usage: %@", error.localizedDescription)
        }
    }
    
    private func updateNetworkStats() async {
        let interface = "en0" // Primary network interface
        
        guard let interfaceData = getNetworkInterfaceData(interface: interface) else {
            return
        }
        
        let currentTime = Date()
        let bytesIn = interfaceData.bytesIn
        let bytesOut = interfaceData.bytesOut
        
        if let lastStats = lastNetworkStats,
           let lastTime = lastNetworkTime {
            let timeDiff = currentTime.timeIntervalSince(lastTime)
            let bytesInDiff = Int64(bytesIn) - Int64(lastStats.bytesIn)
            let bytesOutDiff = Int64(bytesOut) - Int64(lastStats.bytesOut)
            
            // Convert to bytes per second, then to Mbps
            networkDownloadSpeed = Double(bytesInDiff) / timeDiff / 1_000_000 * 8
            networkUploadSpeed = Double(bytesOutDiff) / timeDiff / 1_000_000 * 8
        }
        
        lastNetworkStats = (bytesIn: bytesIn, bytesOut: bytesOut)
        lastNetworkTime = currentTime
    }
    
    private func updateBatteryInfo() async {
        // Simplified battery monitoring to avoid Core Foundation memory issues
        // For now, we'll disable battery monitoring to prevent crashes
        // This can be re-implemented later with proper memory management
        
        // Check if we're on a MacBook (has battery)
        let model = getMacModel()
        if model.contains("MacBook") {
            // Simulate battery level for MacBooks
            batteryLevel = 85.0 // Simulated battery level
            batteryHealth = "Good"
        } else {
            // Desktop Mac - no battery
            batteryLevel = 0
            batteryHealth = "N/A"
        }
    }
    
    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private func updateTemperature() async {
        // Simplified temperature reading based on CPU usage
        // In a real implementation, you'd use IOKit to read from thermal sensors
        // For now, we'll simulate temperature based on CPU usage
        temperature = 30.0 + (cpuUsage * 0.5) // Base temp + CPU load factor
    }
    
    private func updateFanSpeed() async {
        // This would require more complex IOKit calls to read fan speeds
        // For now, we'll simulate based on CPU usage
        fanSpeed = cpuUsage * 50.0 // RPM proportional to CPU usage
    }
    
    // MARK: - Helper Methods
    
    private func getNetworkInterfaceData(interface: String) -> (bytesIn: UInt32, bytesOut: UInt32)? {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0 else { return nil }
        defer { freeifaddrs(ifaddrs) }
        
        var current = ifaddrs
        while current != nil {
            if let addr = current?.pointee {
                if String(cString: addr.ifa_name) == interface {
                    if let data = addr.ifa_data {
                        let ifData = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
                        return (bytesIn: ifData.ifi_ibytes, bytesOut: ifData.ifi_obytes)
                    }
                }
            }
            current = current?.pointee.ifa_next
        }
        
        return nil
    }
}
