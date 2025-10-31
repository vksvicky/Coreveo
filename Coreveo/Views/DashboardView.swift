import SwiftUI

struct DashboardView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @Binding var selectedTab: Int

    var body: some View {
        ScrollView {
            DashboardGrid(monitor: monitor, selectedTab: $selectedTab)
                .padding()
        }
        .navigationTitle("System Dashboard")
    }
}

private struct DashboardGrid: View {
    @ObservedObject var monitor: SystemMonitor
    @Binding var selectedTab: Int
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            cpuCard
            memoryCard
            diskCard
            networkCard
            if monitor.batteryLevel > 0 {
                batteryCard
            }
            temperatureCard
        }
    }
    
    private var cpuCard: some View {
        SystemCard(
            title: "CPU Usage",
            value: "\(Int(monitor.cpuUsage))%",
            icon: "cpu.fill",
            color: .blue,
            progress: monitor.cpuUsage / 100.0
        )
        .onTapGesture { selectedTab = 1 }
    }
    
    private var memoryCard: some View {
        SystemCard(
            title: "Memory Usage",
            value: "\(Int(monitor.memoryUsage))%",
            icon: "memorychip.fill",
            color: .green,
            progress: monitor.memoryUsage / 100.0
        )
        .onTapGesture { selectedTab = 2 }
    }
    
    private var diskCard: some View {
        SystemCard(
            title: "Disk Usage",
            value: "\(Int(monitor.diskUsage))%",
            icon: "externaldrive.fill",
            color: .orange,
            progress: monitor.diskUsage / 100.0
        )
        .onTapGesture { selectedTab = 3 }
    }
    
    private var networkCard: some View {
        NetworkCard(
            uploadSpeed: monitor.networkUploadSpeed,
            downloadSpeed: monitor.networkDownloadSpeed
        )
        .onTapGesture { selectedTab = 4 }
    }
    
    private var batteryCard: some View {
        BatteryCard(level: monitor.batteryLevel, health: monitor.batteryHealth)
            .onTapGesture { selectedTab = 5 }
    }
    
    private var temperatureCard: some View {
        TemperatureCard(temperature: monitor.temperature, fanSpeeds: monitor.fanSpeeds)
            .onTapGesture { selectedTab = 6 }
    }
}

struct SystemCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 2)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct NetworkCard: View {
    let uploadSpeed: Double
    let downloadSpeed: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NetworkCardHeader()
            NetworkCardStats(uploadSpeed: uploadSpeed, downloadSpeed: downloadSpeed)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

private struct NetworkCardHeader: View {
    var body: some View {
        HStack {
            Image(systemName: "network")
                .foregroundColor(.purple)
                .font(.title2)
            Spacer()
            Text("Network")
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

private struct NetworkCardStats: View {
    let uploadSpeed: Double
    let downloadSpeed: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up")
                    .foregroundColor(.red)
                    .font(.caption)
                Text("Upload: \(String(format: "%.1f", uploadSpeed)) Mbps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Image(systemName: "arrow.down")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Download: \(String(format: "%.1f", downloadSpeed)) Mbps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BatteryCard: View {
    let level: Double
    let health: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "battery.100")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Spacer()
                
                Text("\(Int(level))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text("Battery")
                .font(.headline)
                .foregroundColor(.primary)
            
            ProgressView(value: level / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 2)
            
            Text("Health: \(health)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct TemperatureCard: View {
    let temperature: Double
    let fanSpeeds: [Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TemperatureCardHeader(temperature: temperature)
            Text("Temperature")
                .font(.headline)
                .foregroundColor(.primary)
            TemperatureCardFan(fanSpeeds: fanSpeeds)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

private struct TemperatureCardHeader: View {
    let temperature: Double
    
    var body: some View {
        HStack {
            Image(systemName: "thermometer")
                .foregroundColor(.red)
                .font(.title2)
            Spacer()
            Text("\(Int(temperature))°C")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }
}

private struct TemperatureCardFan: View {
    let fanSpeeds: [Double]
    
    var body: some View {
        HStack {
            Image(systemName: "fan")
                .foregroundColor(.blue)
                .font(.caption)
            let avg = fanSpeeds.isEmpty ? 0 : Int(fanSpeeds.reduce(0, +) / Double(fanSpeeds.count))
            Text("Fan (avg): \(avg) RPM")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
}
