import SwiftUI

struct CPUView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CPU Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("CPU Usage: \(Int(SystemMonitor.shared.cpuUsage))%")
                .font(.title2)
            
            ProgressView(value: SystemMonitor.shared.cpuUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("CPU")
    }
}

struct MemoryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Memory Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Memory Usage: \(Int(SystemMonitor.shared.memoryUsage))%")
                .font(.title2)
            
            ProgressView(value: SystemMonitor.shared.memoryUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Memory")
    }
}

struct DiskView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Disk Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Disk Usage: \(Int(SystemMonitor.shared.diskUsage))%")
                .font(.title2)
            
            ProgressView(value: SystemMonitor.shared.diskUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Disk")
    }
}

struct NetworkView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Upload Speed: \(String(format: "%.1f", SystemMonitor.shared.networkUploadSpeed)) Mbps")
                    .font(.title2)
                
                Text("Download Speed: \(String(format: "%.1f", SystemMonitor.shared.networkDownloadSpeed)) Mbps")
                    .font(.title2)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Network")
    }
}

struct BatteryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Battery Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if SystemMonitor.shared.batteryLevel > 0 {
                Text("Battery Level: \(Int(SystemMonitor.shared.batteryLevel))%")
                    .font(.title2)
                
                ProgressView(value: SystemMonitor.shared.batteryLevel / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 3)
                
                Text("Battery Health: \(SystemMonitor.shared.batteryHealth)")
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
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Temperature Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Temperature: \(Int(SystemMonitor.shared.temperature))°C")
                    .font(.title2)
                
                Text("Fan Speed: \(Int(SystemMonitor.shared.fanSpeed)) RPM")
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
