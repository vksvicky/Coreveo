import Foundation

/// Helper utilities for reading system information.
enum SystemInfoReader {
    /// Reads the Mac model name using sysctl.
    static func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    /// Reads network interface data for the specified interface.
    static func getNetworkInterfaceData(interface: String) -> (bytesIn: UInt32, bytesOut: UInt32)? {
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
