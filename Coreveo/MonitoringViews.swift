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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Disk Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Disk Usage: \(Int(monitor.diskUsage))%")
                .font(.title2)
            
            ProgressView(value: monitor.diskUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Disk")
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
        VStack(alignment: .leading, spacing: 20) {
            Text("Temperature Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Temperature: \(Int(monitor.temperature))°C")
                    .font(.title2)
                
                Text("Fan Speed: \(Int(monitor.fanSpeed)) RPM")
                    .font(.title2)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Temperature")
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
