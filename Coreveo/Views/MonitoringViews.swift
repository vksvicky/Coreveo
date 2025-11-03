import SwiftUI

struct CPUView: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CPUOverallUsageCard(monitor: monitor)
                
                if !monitor.perCoreUsage.isEmpty {
                    CPUPerCoreSection(coreUsages: monitor.perCoreUsage)
                }
            }
            .padding()
        }
        .navigationTitle("CPU")
    }
}

private struct CPUOverallUsageCard: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall CPU Usage")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(alignment: .center, spacing: 16) {
                CPUGauge(monitor: monitor)
                CPUStatistics(perCoreUsage: monitor.perCoreUsage)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

private struct CPUGauge: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                .frame(width: 100, height: 100)
            
            Circle()
                .trim(from: 0, to: monitor.cpuUsage / 100.0)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: monitor.cpuUsage)
            
            VStack(spacing: 2) {
                Text("\(Int(monitor.cpuUsage))%")
                    .font(.system(size: 24, weight: .bold))
                Text("CPU")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct CPUStatistics: View {
    let perCoreUsage: [Double]
    
    private var activeCores: Int {
        perCoreUsage.filter { $0 > 0.05 }.count
    }
    
    private var peakUsage: String {
        if let maxUsage = perCoreUsage.max() {
            return "\(Int(maxUsage * 100))%"
        }
        return "—"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatRow(label: "Cores:", value: "\(perCoreUsage.count)")
            StatRow(label: "Active Cores:", value: "\(activeCores)")
            StatRow(label: "Peak Core:", value: peakUsage)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

private struct CPUPerCoreSection: View {
    let coreUsages: [Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Core Usage")
                .font(.title2)
                .fontWeight(.semibold)
            
            PerCoreUsageGrid(coreUsages: coreUsages)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct PerCoreUsageGrid: View {
    let coreUsages: [Double]
    
    // Adaptive column count based on core count
    // Current max: M3 Ultra with 80 cores (2025)
    var columnCount: Int {
        switch coreUsages.count {
        case 0...4:
            return 1      // Entry-level (MacBook Air base)
        case 5...8:
            return 2      // Mid-range (MacBook Air, M4)
        case 9...16:
            return 3     // Pro models (M4 Pro, M3 Max)
        case 17...32:
            return 4    // High-end (Mac Pro Intel, M4 Max)
        case 33...64:
            return 6    // Ultra-high (M4 Max 40-core, M3 Ultra base)
        default:
            return 8         // Maximum density (M3 Ultra 80-core+, future)
        }
    }
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(coreUsages.enumerated()), id: \.offset) { index, usage in
                CoreUsageCard(coreNumber: index + 1, usage: usage)
            }
        }
    }
}

struct CoreUsageCard: View {
    let coreNumber: Int
    let usage: Double
    
    var usageColor: Color {
        switch usage {
        case 0..<0.3:
            return .green
        case 0.3..<0.6:
            return .yellow
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            CoreUsageHeader(coreNumber: coreNumber, usage: usage)
            CoreUsageProgressBar(usage: usage, color: usageColor)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

private struct CoreUsageHeader: View {
    let coreNumber: Int
    let usage: Double
    
    var body: some View {
        HStack {
            Text("Core \(coreNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(Int(usage * 100))%")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

private struct CoreUsageProgressBar: View {
    let usage: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                    .cornerRadius(3)
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * usage, height: 6)
                    .cornerRadius(3)
                    .animation(.easeInOut(duration: 0.3), value: usage)
            }
        }
        .frame(height: 6)
    }
}

struct MemoryView: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Memory Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Memory Usage: \(Int(monitor.memoryUsage))%")
                .font(.title2)
            
            ProgressView(value: monitor.memoryUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Memory")
    }
}

struct DiskView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @StateObject private var smartMonitor = SmartDiskMonitor()
    @State private var isRefreshing = false
    @State private var fdaCheckTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Basic Disk Usage Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Disk Monitoring")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Disk Usage: \(Int(monitor.diskUsage))%")
                        .font(.title2)
                    
                    ProgressView(value: monitor.diskUsage / 100.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .scaleEffect(y: 3)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // S.M.A.R.T. Health Monitoring Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Disk Health (S.M.A.R.T.)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if smartMonitor.canReadSmartData() {
                            Button(action: refreshSmartData) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRefreshing)
                        }
                    }
                    
                    Group {
                        if smartMonitor.canReadSmartData() {
                            // FDA granted - show disk health data
                            Text(verbatim: "DEBUG: FDA granted, disks.count=\(smartMonitor.disks.count), isRefreshing=\(isRefreshing)")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            if smartMonitor.disks.isEmpty && !isRefreshing {
                                emptySmartDataView
                            } else if isRefreshing {
                                HStack {
                                    Spacer()
                                    ProgressView("Checking disk health...")
                                    Spacer()
                                }
                                .padding()
                            } else {
                                smartDiskList
                            }
                        } else {
                            // FDA not granted - show permission required message
                            Text(verbatim: "DEBUG: FDA NOT granted")
                                .font(.caption)
                                .foregroundColor(.red)
                            fdaRequiredView
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Disk")
        .onAppear {
            checkAndRefresh()
            startFDACheckTimer()
        }
        .onDisappear {
            stopFDACheckTimer()
        }
    }
    
    private func checkAndRefresh() {
        let canRead = smartMonitor.canReadSmartData()
        if canRead && smartMonitor.disks.isEmpty {
            smartMonitor.refresh()
        }
    }
    
    private func startFDACheckTimer() {
        // Check FDA status every 2 seconds while the view is visible
        // This auto-refreshes when user grants permission in System Settings
        fdaCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkAndRefresh()
        }
    }
    
    private func stopFDACheckTimer() {
        fdaCheckTimer?.invalidate()
        fdaCheckTimer = nil
    }
    
    // MARK: - S.M.A.R.T. Components
    
    @ViewBuilder
    private var smartDiskList: some View {
        VStack(spacing: 12) {
            ForEach(smartMonitor.disks) { disk in
                DiskHealthCard(disk: disk, smartData: smartMonitor.smartData[disk.identifier])
            }
        }
    }
    
    @ViewBuilder
    private var emptySmartDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("No Disks Found")
                .font(.headline)
            
            Text("No S.M.A.R.T.-capable disks detected")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Scan for Disks") {
                refreshSmartData()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
    
    @ViewBuilder
    private var fdaRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Full Disk Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Full Disk Access permission is required to read disk health (S.M.A.R.T.) data. Please grant this permission in System Settings to enable disk health monitoring.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    PermissionManager.shared.openFullDiskAccessSettings()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open System Settings")
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    if smartMonitor.canReadSmartData() {
                        smartMonitor.refresh()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check Permission")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(maxWidth: 500)
    }
    
    private func refreshSmartData() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        smartMonitor.refresh()
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // Small delay for UX
            isRefreshing = false
        }
    }
}

struct NetworkView: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Upload Speed: \(String(format: "%.1f", monitor.networkUploadSpeed)) Mbps")
                    .font(.title2)
                
                Text("Download Speed: \(String(format: "%.1f", monitor.networkDownloadSpeed)) Mbps")
                    .font(.title2)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Network")
    }
}

struct BatteryView: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Battery Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if monitor.batteryLevel > 0 {
                Text("Battery Level: \(Int(monitor.batteryLevel))%")
                    .font(.title2)
                
                ProgressView(value: monitor.batteryLevel / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 3)
                
                Text("Battery Health: \(monitor.batteryHealth)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            } else {
                Text("No battery detected")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Battery")
    }
}

struct TemperatureView: View {
    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Text("Temperature Monitoring")
                //     .font(.largeTitle)
                //     .fontWeight(.bold)

                // Quick summary
                HStack(spacing: 24) {
                    SummaryTile(title: "CPU", value: "\(Int(monitor.temperature))°C", systemImage: "cpu")
                    if !monitor.fanSpeeds.isEmpty {
                        let avg = Int(monitor.fanSpeeds.reduce(0,+)/Double(monitor.fanSpeeds.count))
                        SummaryTile(title: "Fans (avg)", value: "\(avg) RPM", systemImage: "fan")
                    }
                }

                // Fans section
                if !monitor.fanSpeeds.isEmpty {
                    SectionHeader(title: "Fans")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(monitor.fanSpeeds.enumerated()), id: \.offset) { idx, speed in
                            KeyValueRow(key: idx == 0 ? "Left Side" : "Right Side", value: "\(Int(speed)) RPM")
                        }
                    }
                }

                // Temperatures grouped
                if !monitor.temperatureSensors.isEmpty {
                    SectionHeader(title: "Temperatures")
                    TemperatureDetailList(sensors: monitor.temperatureSensors)
                }
            }
            .padding()
        }
        .navigationTitle("Temperature")
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let systemImage: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.title3).fontWeight(.semibold)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
        .font(.subheadline)
    }
}

private struct TemperatureDetailList: View {
    let sensors: [String: Double]

    private var groups: [String: [(String, Double)]] {
        var map: [String: [(String, Double)]] = [:]
        for (name, value) in sensors {
            let group = category(for: name)
            map[group, default: []].append((name, value))
        }
        return map
    }

    private func category(for name: String) -> String {
        let n = name.lowercased()
        if n.hasPrefix("efficiency core") || n.hasPrefix("performance core") { return "CPU" }
        if n.contains("gpu") { return "GPU" }
        if n.contains("battery") { return "Battery" }
        if n.contains("airflow") { return "Airflow" }
        if n.contains("trackpad") { return "Trackpad" }
        if n.contains("charger") { return "Charger" }
        if n.contains("power supply") { return "Power Supply" }
        if n.contains("thunderbolt") { return "Thunderbolt" }
        if n.contains("wireless") { return "Wireless" }
        if n.contains("ssd") { return "SSD" }
        return "Other"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 8) {
                    Text(key).font(.subheadline).foregroundColor(.secondary)
                    ForEach(groups[key]!.sorted { $0.0 < $1.0 }, id: \.0) { item in
                        TemperatureBarRow(name: item.0, value: item.1)
                    }
                }
            }
        }
    }
}

private struct TemperatureBarRow: View {
    let name: String
    let value: Double
    private var color: Color {
        switch value {
            case ..<40: return .green
            case 40..<70: return .yellow
            default: return .red
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                Spacer()
                Text("\(Int(value))°C")
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(value, 100) / 100.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .font(.subheadline)
    }
}

struct ProcessView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Process Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Process monitoring will be implemented here")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Processes")
    }
}

#Preview {
    CPUView()
}
