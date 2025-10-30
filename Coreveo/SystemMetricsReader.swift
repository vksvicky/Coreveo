import AppKit
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import SystemConfiguration

/// Helper utilities for reading individual system metrics.
/// All methods are nonisolated and async to support concurrent execution.
enum SystemMetricsReader {
    /// Reads overall CPU usage using host_statistics.
    /// Returns a CPUTicks struct containing user, system, idle, and nice ticks.
    static func readCPUTicks() -> CPUTicks? {
        let host = mach_host_self()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuLoadInfo = host_cpu_load_info_data_t()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        return CPUTicks(
            user: UInt64(cpuLoadInfo.cpu_ticks.0),
            system: UInt64(cpuLoadInfo.cpu_ticks.1),
            idle: UInt64(cpuLoadInfo.cpu_ticks.2),
            nice: UInt64(cpuLoadInfo.cpu_ticks.3)
        )
    }
    
    /// Calculates CPU usage percentage from two tick snapshots.
    static func calculateCPUUsage(previous: CPUTicks, current: CPUTicks) -> Double? {
        let userDelta = current.user >= previous.user ? (current.user - previous.user) : 0
        let systemDelta = current.system >= previous.system ? (current.system - previous.system) : 0
        let idleDelta = current.idle >= previous.idle ? (current.idle - previous.idle) : 0
        let niceDelta = current.nice >= previous.nice ? (current.nice - previous.nice) : 0
        
        let totalDelta = Double(userDelta + systemDelta + idleDelta + niceDelta)
        
        guard totalDelta > 0 else { return nil }
        
        let activeDelta = Double(userDelta + systemDelta + niceDelta)
        return min(max((activeDelta / totalDelta) * 100.0, 0), 100)
    }
    
    /// Reads memory usage statistics using vm_statistics64.
    /// Returns usage as a percentage (0-100).
    static func readMemoryUsage() -> Double? {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        let pageSize = vm_kernel_page_size
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let freeMemory = UInt64(vmStats.free_count) * UInt64(pageSize)
        let usedMemory = totalMemory - freeMemory
        
        return (Double(usedMemory) / Double(totalMemory)) * 100.0
    }
    
    /// Reads disk usage for the root filesystem.
    /// Returns usage as a percentage (0-100).
    static func readDiskUsage() -> Double? {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            if let totalSize = attributes[.systemSize] as? NSNumber,
               let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let usedSize = totalSize.uint64Value - freeSize.uint64Value
                return (Double(usedSize) / Double(totalSize.uint64Value)) * 100.0
            }
        } catch {
            NSLog("Error getting disk usage: %@", error.localizedDescription)
        }
        
        return nil
    }
    
    /// Calculates network speeds from two snapshots.
    /// Returns (downloadSpeed, uploadSpeed) in Mbps.
    static func calculateNetworkSpeeds(
        previous: (bytesIn: UInt32, bytesOut: UInt32, time: Date),
        current: (bytesIn: UInt32, bytesOut: UInt32, time: Date)
    ) -> (downloadSpeed: Double, uploadSpeed: Double) {
        let timeDiff = current.time.timeIntervalSince(previous.time)
        let bytesInDiff = Int64(current.bytesIn) - Int64(previous.bytesIn)
        let bytesOutDiff = Int64(current.bytesOut) - Int64(previous.bytesOut)
        
        // Convert to bytes per second, then to Mbps
        let downloadSpeed = Double(bytesInDiff) / timeDiff / 1_000_000 * 8
        let uploadSpeed = Double(bytesOutDiff) / timeDiff / 1_000_000 * 8
        
        return (downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed)
    }
    
    /// Simulates battery level for the current device.
    /// Returns (level, health) tuple.
    static func readBatteryInfo() -> (level: Double, health: String) {
        let model = SystemInfoReader.getMacModel()
        if model.contains("MacBook") {
            return (level: 85.0, health: "Good")
        } else {
            return (level: 0, health: "N/A")
        }
    }
    
    /// Simulates temperature based on CPU usage.
    /// Returns temperature in Celsius.
    static func simulateTemperature(cpuUsage: Double) -> Double {
        return 30.0 + (cpuUsage * 0.5)
    }
    
    /// Simulates fan speed based on CPU usage.
    /// Returns RPM.
    static func simulateFanSpeed(cpuUsage: Double) -> Double {
        return cpuUsage * 50.0
    }
}
