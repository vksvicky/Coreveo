import SwiftUI

/// Disk Health (S.M.A.R.T.) monitoring view
/// Checks FDA permission before displaying disk health data
struct DiskHealthView: View {
    @StateObject private var monitor = SmartDiskMonitor()
    @State private var showingFDAAlert = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            if monitor.canReadSmartData() {
                // FDA granted - show disk health data
                diskHealthContent
            } else {
                // FDA not granted - show permission required message
                fdaRequiredView
            }
        }
        .navigationTitle("Disk Health")
        .onAppear {
            checkPermissionAndLoad()
        }
    }
    
    // MARK: - Disk Health Content
    
    @ViewBuilder
    private var diskHealthContent: some View {
        if monitor.disks.isEmpty && !isRefreshing {
            emptyStateView
        } else {
            VStack(spacing: 0) {
                // Header with refresh button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disk Health (S.M.A.R.T.)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let lastUpdate = monitor.lastUpdateTime {
                            Text("Last updated: \(lastUpdate, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: refreshData) {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .imageScale(.large)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Disk list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(monitor.disks, id: \.identifier) { disk in
                            DiskHealthCard(
                                disk: disk,
                                smartData: monitor.getSmartData(for: disk)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - FDA Required View
    
    private var fdaRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Full Disk Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(monitor.getFDARequiredMessage())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button(action: openSystemSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open System Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: checkPermissionAndLoad) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check Permission")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Disks Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("No physical disks were detected on this system.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Button(action: refreshData) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func checkPermissionAndLoad() {
        if monitor.canReadSmartData() {
            refreshData()
        } else {
            NSLog("[DiskHealthView] Full Disk Access not granted")
        }
    }
    
    private func refreshData() {
        isRefreshing = true
        
        Task {
            // Run on background thread
            await Task.detached {
                await MainActor.run {
                    monitor.refresh()
                }
            }.value
            
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Disk Health Card

public struct DiskHealthCard: View {
    public let disk: DiskInfo
    public let smartData: SmartData?
    
    public init(disk: DiskInfo, smartData: SmartData?) {
        self.disk = disk
        self.smartData = smartData
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: diskIcon)
                    .font(.title)
                    .foregroundColor(healthColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(disk.name)
                        .font(.headline)
                    
                    Text(disk.identifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let smartData = smartData {
                    HealthBadge(health: smartData.health)
                }
            }
            
            if let smartData = smartData {
                Divider()
                
                // S.M.A.R.T. Data Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    if let temp = smartData.temperature {
                        MetricItem(
                            icon: "thermometer",
                            label: "Temperature",
                            value: "\(temp)°C",
                            color: temperatureColor(temp)
                        )
                    }
                    
                    if let wear = smartData.wearLevelPercent {
                        MetricItem(
                            icon: "chart.line.uptrend.xyaxis",
                            label: "Wear Level",
                            value: "\(wear)%",
                            color: wearLevelColor(wear)
                        )
                    }
                    
                    if let hours = smartData.powerOnHours {
                        MetricItem(
                            icon: "clock",
                            label: "Power On Hours",
                            value: "\(formatHours(hours))",
                            color: .blue
                        )
                    }
                    
                    if let spare = smartData.availableSparePercent {
                        MetricItem(
                            icon: "cpu",
                            label: "Available Spare",
                            value: "\(spare)%",
                            color: .green
                        )
                    }
                }
                
                // Model and Serial (if available)
                if smartData.model != nil || smartData.serialNumber != nil {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let model = smartData.model {
                            HStack {
                                Text("Model:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(model)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        if let serial = smartData.serialNumber {
                            HStack {
                                Text("Serial:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(serial)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            } else {
                Divider()
                
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("S.M.A.R.T. data not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var diskIcon: String {
        if disk.name.contains("SSD") || disk.name.contains("APPLE") {
            return "internaldrive"
        } else {
            return "externaldrive"
        }
    }
    
    private var healthColor: Color {
        guard let smartData = smartData else { return .secondary }
        
        switch smartData.health {
        case "Healthy": return .green
        case "Warning": return .orange
        case "Critical": return .red
        default: return .secondary
        }
    }
    
    private func temperatureColor(_ temp: Int) -> Color {
        if temp >= 70 { return .red }
        if temp >= 55 { return .orange }
        return .blue
    }
    
    private func wearLevelColor(_ wear: Int) -> Color {
        if wear >= 90 { return .red }
        if wear >= 70 { return .orange }
        return .green
    }
    
    private func formatHours(_ hours: Int) -> String {
        let days = hours / 24
        if days > 365 {
            let years = Double(days) / 365.0
            return String(format: "%.1f years", years)
        } else {
            return "\(days) days"
        }
    }
}

// MARK: - Supporting Views

struct HealthBadge: View {
    let health: String
    
    var body: some View {
        Text(health)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(12)
    }
    
    private var backgroundColor: Color {
        switch health {
        case "Healthy": return .green
        case "Warning": return .orange
        case "Critical": return .red
        default: return .gray
        }
    }
}

struct MetricItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct DiskHealthView_Previews: PreviewProvider {
    static var previews: some View {
        DiskHealthView()
            .frame(width: 600, height: 400)
    }
}

