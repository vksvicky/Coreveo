import Foundation

/// Represents a physical disk that can be monitored
public struct DiskInfo: Identifiable {
    public var id: String { identifier }
    
    let identifier: String  // e.g., "disk0"
    let name: String        // e.g., "APPLE SSD AP0512Q"
    let devicePath: String  // e.g., "/dev/disk0"
}

/// S.M.A.R.T. health data for a disk
public struct SmartData {
    let temperature: Int?           // Celsius
    let health: String              // "Healthy", "Warning", "Critical", "Unknown"
    let powerOnHours: Int?          // Total hours disk has been powered on
    let wearLevelPercent: Int?      // 0-100, higher = more worn (SSDs only)
    let availableSparePercent: Int? // Remaining spare blocks (SSDs only)
    let model: String?
    let serialNumber: String?
}

/// Protocol for reading S.M.A.R.T. data from disks
public protocol SmartReading {
    func getAvailableDisks() -> [DiskInfo]
    func readSmartData(for disk: DiskInfo) -> SmartData?
}

/// System implementation that reads real S.M.A.R.T. data
/// Requires Full Disk Access permission
public final class SystemSmartReader: SmartReading {
    
    public init() {}
    
    /// Get list of available physical disks
    public func getAvailableDisks() -> [DiskInfo] {
        var disks: [DiskInfo] = []
        
        // Use diskutil to list physical disks
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list", "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            // Parse plist output
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                if let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
                    for diskDict in allDisks {
                        if let diskIdentifier = diskDict["DeviceIdentifier"] as? String {
                            let hasPrefix = diskIdentifier.hasPrefix("disk")
                            // Check if it's a partition (e.g., disk0s1, disk0s2)
                            let isPartition = diskIdentifier.range(of: "s\\d", options: .regularExpression) != nil
                            let size = diskDict["Size"] as? Int64
                            let content = diskDict["Content"] as? String
                            
                            // Check for physical/internal disks vs synthesized/disk images
                            let hasPartitionScheme = content?.contains("partition_scheme") ?? false
                            let isSynthesized = (content?.contains("APFS Container") ?? false) || 
                                              (content?.contains("CoreStorage") ?? false)
                            let hasPhysicalStores = diskDict["APFSPhysicalStores"] != nil
                            let hasAPFSVolumes = diskDict["APFSVolumes"] != nil
                            let isPhysicalDisk = hasPartitionScheme && !isSynthesized && !hasPhysicalStores && !hasAPFSVolumes
                            
                            if hasPrefix && !isPartition && isPhysicalDisk {
                                if let diskSize = size, diskSize > 0 {
                                    // Get disk name using diskutil info
                                    let name = getDiskName(identifier: diskIdentifier)
                                    
                                    // Filter out disk images by name
                                    let isDiskImage = name.contains("Disk Image") || 
                                                     name.contains("disk image") ||
                                                     name.contains("Apple APFS Media")
                                    
                                    if !isDiskImage {
                                        disks.append(DiskInfo(
                                            identifier: diskIdentifier,
                                            name: name,
                                            devicePath: "/dev/\(diskIdentifier)"
                                        ))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            NSLog("[SmartReader] Error listing disks: \(error.localizedDescription)")
        }
        
        return disks
    }
    
    /// Read S.M.A.R.T. data for a specific disk
    /// Returns nil if FDA is not granted or disk doesn't support S.M.A.R.T.
    public func readSmartData(for disk: DiskInfo) -> SmartData? {
        // Check FDA before attempting to read
        guard PermissionManager.shared.checkFullDiskAccessPermission() else {
            return nil
        }
        
        // Try native macOS tools first (diskutil via IOKit)
        // This works without requiring smartctl installation
        if let data = readUsingIOKit(disk: disk) {
            return data
        }
        
        // Fallback: Try smartctl if installed (more comprehensive data)
        if let data = readUsingSmartctl(disk: disk) {
            return data
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func getDiskName(identifier: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", identifier]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for "Device / Media Name" line
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("Device / Media Name:") || line.contains("Media Name:") {
                        let parts = line.components(separatedBy: ":")
                        if parts.count > 1 {
                            return parts[1].trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        } catch {
            NSLog("[SmartReader] Error getting disk name: \(error.localizedDescription)")
        }
        
        return identifier
    }
    
    private func readUsingSmartctl(disk: DiskInfo) -> SmartData? {
        // Check if smartctl is installed
        let smartctlPath = "/opt/homebrew/bin/smartctl"
        guard FileManager.default.fileExists(atPath: smartctlPath) else {
            NSLog("[SmartReader] smartctl not found at \(smartctlPath)")
            return nil
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: smartctlPath)
        process.arguments = ["-a", disk.devicePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return SmartDataParser().parse(smartctlOutput: output)
            }
        } catch {
            NSLog("[SmartReader] Error running smartctl: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func readUsingIOKit(disk: DiskInfo) -> SmartData? {
        // Use diskutil to get SMART status (most reliable native method)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", disk.identifier]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                // Extract SMART status
                let smartStatus = plist["SMARTStatus"] as? String ?? "Not Supported"
                let isVerified = smartStatus == "Verified"
                
                // Extract model and serial
                let model = extractModel(from: plist)
                let serialNumber = extractSerial(from: plist)
                
                // Try to get temperature from IORegistry
                let temperature = getTemperatureFromIORegistry(diskIdentifier: disk.identifier)
                
                // Try to get SSD-specific data
                let (wearLevel, availableSpare) = getSSDWearData(from: plist)
                
                // Try to get power-on hours
                let powerOnHours = getPowerOnHours(from: plist)
                
                // Create SMART data from available info
                if isVerified || temperature != nil || model != nil {
                    let health = determineHealth(smartStatus: smartStatus, wearLevel: wearLevel, temperature: temperature)
                    return SmartData(
                        temperature: temperature,
                        health: health,
                        powerOnHours: powerOnHours,
                        wearLevelPercent: wearLevel,
                        availableSparePercent: availableSpare,
                        model: model,
                        serialNumber: serialNumber
                    )
                }
            }
        } catch {
            NSLog("[SmartReader] Error running diskutil: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func extractModel(from plist: [String: Any]) -> String? {
        // Try multiple keys for model information
        if let model = plist["MediaName"] as? String {
            return model
        }
        if let model = plist["DeviceMediaName"] as? String {
            return model
        }
        if let model = plist["IORegistryEntryName"] as? String {
            return model
        }
        return nil
    }
    
    private func extractSerial(from plist: [String: Any]) -> String? {
        // Try multiple keys for serial number
        if let serial = plist["DiskUUID"] as? String {
            return serial
        }
        if let serial = plist["VolumeUUID"] as? String {
            return serial
        }
        // Note: Physical disk serial numbers are often not exposed via diskutil
        // They require direct IOKit access
        return nil
    }
    
    private func getSSDWearData(from plist: [String: Any]) -> (wearLevel: Int?, availableSpare: Int?) {
        // Try to extract SSD wear data if available in plist
        // Note: Apple SSDs typically don't expose this via diskutil
        
        // Check for NVMe-specific fields (some third-party drives expose this)
        if let percentageUsed = plist["PercentageUsed"] as? Int {
            return (percentageUsed, nil)
        }
        
        // Check for available spare (NVMe drives)
        if let availableSpare = plist["AvailableSpare"] as? Int {
            return (nil, availableSpare)
        }
        
        // Not available via diskutil - requires smartctl or direct IOKit
        return (nil, nil)
    }
    
    private func getPowerOnHours(from plist: [String: Any]) -> Int? {
        // Try to extract power-on hours if available
        // Note: Rarely available via diskutil, usually requires smartctl
        
        if let powerOnHours = plist["PowerOnHours"] as? Int {
            return powerOnHours
        }
        
        if let powerCycleCount = plist["PowerCycleCount"] as? Int {
            // Some drives expose cycle count instead of hours
            // Rough estimate: 1 cycle ≈ 8 hours of use
            return powerCycleCount * 8
        }
        
        return nil
    }
    
    private func determineHealth(smartStatus: String, wearLevel: Int?, temperature: Int?) -> String {
        // Check SMART status first
        if smartStatus == "Verified" {
            // Check temperature if available
            if let temp = temperature, temp > 70 {
                return "Warning"  // High temperature
            }
            
            // Check wear level if available
            if let wear = wearLevel, wear > 80 {
                return "Warning"  // High wear
            }
            
            return "Healthy"
        } else if smartStatus == "Failing" {
            return "Critical"
        } else if smartStatus == "Not Supported" {
            return "Unknown"
        }
        
        return "Unknown"
    }
    
    private func getTemperatureFromIORegistry(diskIdentifier: String) -> Int? {
        // Try to read temperature using system_profiler (simpler than direct IOKit)
        // This provides NVMe temperature data if available
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPNVMeDataType", "-xml"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] {
                // system_profiler returns an array with data
                for item in plist {
                    if let items = item["_items"] as? [[String: Any]] {
                        for nvmeItem in items {
                            // Check if this is our disk
                            if let bsdName = nvmeItem["bsd_name"] as? String,
                               bsdName == diskIdentifier {
                                // Try to extract temperature
                                if let tempString = nvmeItem["temperature"] as? String {
                                    // Temperature is usually in format "XX °C" or "XX C"
                                    let components = tempString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                                    if let tempValue = components.compactMap({ Int($0) }).first {
                                        return tempValue
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            // Silently fail - temperature is optional data
        }
        
        // Temperature not available via system_profiler
        // Would require direct IOKit calls to AppleANS2Controller or smartctl
        return nil
    }
}

/// Parses smartctl output to extract S.M.A.R.T. data
public final class SmartDataParser {
    
    public init() {}
    
    public func parse(smartctlOutput: String) -> SmartData? {
        guard !smartctlOutput.isEmpty else { return nil }
        
        // Check for error indicators
        if smartctlOutput.contains("command not found") ||
           smartctlOutput.contains("Permission denied") ||
           smartctlOutput.contains("Unable to detect") {
            return nil
        }
        
        let lines = smartctlOutput.components(separatedBy: .newlines)
        
        var temperature: Int?
        var powerOnHours: Int?
        var wearLevel: Int?
        var availableSpare: Int?
        var model: String?
        var serialNumber: String?
        var criticalWarning: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Extract model
            if trimmed.hasPrefix("Model Number:") || trimmed.hasPrefix("Device Model:") {
                model = extractValue(from: trimmed)
            }
            
            // Extract serial number
            if trimmed.hasPrefix("Serial Number:") {
                serialNumber = extractValue(from: trimmed)
            }
            
            // Extract temperature
            if trimmed.hasPrefix("Temperature:") {
                if let tempValue = extractIntValue(from: trimmed, pattern: #"(\d+)\s*Celsius"#) {
                    temperature = tempValue
                }
            }
            
            // Extract power on hours
            if trimmed.hasPrefix("Power On Hours:") || trimmed.hasPrefix("Power_On_Hours:") {
                if let hours = extractIntValue(from: trimmed, pattern: #"(\d+)"#) {
                    powerOnHours = hours
                }
            }
            
            // Extract wear level (SSD)
            if trimmed.hasPrefix("Percentage Used:") {
                if let wear = extractIntValue(from: trimmed, pattern: #"(\d+)%"#) {
                    wearLevel = wear
                }
            }
            
            // Extract available spare (SSD)
            if trimmed.hasPrefix("Available Spare:") {
                if let spare = extractIntValue(from: trimmed, pattern: #"(\d+)%"#) {
                    availableSpare = spare
                }
            }
            
            // Extract critical warning
            if trimmed.hasPrefix("Critical Warning:") {
                criticalWarning = extractValue(from: trimmed)
            }
        }
        
        // Determine health status
        let health = determineHealth(
            criticalWarning: criticalWarning,
            wearLevel: wearLevel,
            availableSpare: availableSpare
        )
        
        // Only return data if we extracted something useful
        guard temperature != nil || powerOnHours != nil || wearLevel != nil else {
            return nil
        }
        
        return SmartData(
            temperature: temperature,
            health: health,
            powerOnHours: powerOnHours,
            wearLevelPercent: wearLevel,
            availableSparePercent: availableSpare,
            model: model,
            serialNumber: serialNumber
        )
    }
    
    // MARK: - Private Helpers
    
    private func extractValue(from line: String) -> String? {
        let parts = line.components(separatedBy: ":")
        guard parts.count > 1 else { return nil }
        return parts[1].trimmingCharacters(in: .whitespaces)
    }
    
    private func extractIntValue(from line: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Int(line[captureRange])
    }
    
    private func determineHealth(
        criticalWarning: String?,
        wearLevel: Int?,
        availableSpare: Int?
    ) -> String {
        // Check critical warning (NVMe)
        if let warning = criticalWarning, warning != "0x00" && warning != "0" {
            return "Critical"
        }
        
        // Check wear level
        if let wear = wearLevel {
            if wear >= 90 {
                return "Critical"
            } else if wear >= 70 {
                return "Warning"
            }
        }
        
        // Check available spare
        if let spare = availableSpare {
            if spare <= 10 {
                return "Critical"
            } else if spare <= 30 {
                return "Warning"
            }
        }
        
        // Default to healthy if we have any data
        if wearLevel != nil || availableSpare != nil || criticalWarning != nil {
            return "Healthy"
        }
        
        return "Unknown"
    }
}

/// High-level monitor that manages S.M.A.R.T. disk monitoring
/// Handles FDA checks and provides user-friendly messages
@MainActor
public final class SmartDiskMonitor: ObservableObject {
    
    @Published public private(set) var disks: [DiskInfo] = []
    @Published public private(set) var smartData: [String: SmartData] = [:] // diskIdentifier -> data
    @Published public private(set) var lastUpdateTime: Date?
    
    private let reader: SmartReading
    
    public init(reader: SmartReading = SystemSmartReader()) {
        self.reader = reader
    }
    
    /// Check if S.M.A.R.T. data can be read (requires FDA)
    public func canReadSmartData() -> Bool {
        return PermissionManager.shared.checkFullDiskAccessPermission()
    }
    
    /// Get user-friendly message when FDA is required
    public func getFDARequiredMessage() -> String {
        return "Full Disk Access permission is required to read disk health (S.M.A.R.T.) data. Please grant this permission in System Settings to enable disk health monitoring."
    }
    
    /// Refresh disk list and S.M.A.R.T. data
    public func refresh() {
        guard canReadSmartData() else {
            return
        }
        
        // Get available disks
        disks = reader.getAvailableDisks()
        
        // Read S.M.A.R.T. data for each disk
        var newSmartData: [String: SmartData] = [:]
        for disk in disks {
            if let data = reader.readSmartData(for: disk) {
                newSmartData[disk.identifier] = data
            }
        }
        
        smartData = newSmartData
        lastUpdateTime = Date()
    }
    
    /// Get S.M.A.R.T. data for a specific disk
    public func getSmartData(for disk: DiskInfo) -> SmartData? {
        return smartData[disk.identifier]
    }
}

