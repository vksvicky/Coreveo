import SwiftUI

struct CPUView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("CPU Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("CPU Usage: \(Int(systemMonitor.cpuUsage))%")
                .font(.title2)
            
            ProgressView(value: systemMonitor.cpuUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("CPU")
    }
}

struct MemoryView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Memory Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Memory Usage: \(Int(systemMonitor.memoryUsage))%")
                .font(.title2)
            
            ProgressView(value: systemMonitor.memoryUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Memory")
    }
}

struct DiskView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Disk Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Disk Usage: \(Int(systemMonitor.diskUsage))%")
                .font(.title2)
            
            ProgressView(value: systemMonitor.diskUsage / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 3)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Disk")
    }
}

struct NetworkView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Network Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Upload Speed: \(String(format: "%.1f", systemMonitor.networkUploadSpeed)) Mbps")
                    .font(.title2)
                
                Text("Download Speed: \(String(format: "%.1f", systemMonitor.networkDownloadSpeed)) Mbps")
                    .font(.title2)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Network")
    }
}

struct BatteryView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Battery Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if systemMonitor.batteryLevel > 0 {
                Text("Battery Level: \(Int(systemMonitor.batteryLevel))%")
                    .font(.title2)
                
                ProgressView(value: systemMonitor.batteryLevel / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 3)
                
                Text("Battery Health: \(systemMonitor.batteryHealth)")
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
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Temperature Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Temperature: \(Int(systemMonitor.temperature))°C")
                    .font(.title2)
                
                Text("Fan Speed: \(Int(systemMonitor.fanSpeed)) RPM")
                    .font(.title2)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Temperature")
    }
}

struct ProcessView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
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
        .environmentObject(SystemMonitor())
}
