import SwiftUI

struct DashboardView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                // CPU Card
                SystemCard(
                    title: "CPU Usage",
                    value: "\(Int(SystemMonitor.shared.cpuUsage))%",
                    icon: "cpu.fill",
                    color: .blue,
                    progress: SystemMonitor.shared.cpuUsage / 100.0
                )
                
                // Memory Card
                SystemCard(
                    title: "Memory Usage",
                    value: "\(Int(SystemMonitor.shared.memoryUsage))%",
                    icon: "memorychip.fill",
                    color: .green,
                    progress: SystemMonitor.shared.memoryUsage / 100.0
                )
                
                // Disk Card
                SystemCard(
                    title: "Disk Usage",
                    value: "\(Int(SystemMonitor.shared.diskUsage))%",
                    icon: "externaldrive.fill",
                    color: .orange,
                    progress: SystemMonitor.shared.diskUsage / 100.0
                )
                
                // Network Card
                NetworkCard(
                    uploadSpeed: SystemMonitor.shared.networkUploadSpeed,
                    downloadSpeed: SystemMonitor.shared.networkDownloadSpeed
                )
                
                // Battery Card (if available)
                if SystemMonitor.shared.batteryLevel > 0 {
                    BatteryCard(
                        level: SystemMonitor.shared.batteryLevel,
                        health: SystemMonitor.shared.batteryHealth
                    )
                }
                
                // Temperature Card
                TemperatureCard(
                    temperature: SystemMonitor.shared.temperature,
                    fanSpeed: SystemMonitor.shared.fanSpeed
                )
            }
            .padding()
        }
        .navigationTitle("System Dashboard")
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
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Spacer()
                
                Text("Network")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
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
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
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
    let fanSpeed: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            Text("Temperature")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "fan")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Fan: \(Int(fanSpeed)) RPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    DashboardView()
}
