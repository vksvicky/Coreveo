import SwiftUI
import AppKit

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Coreveo")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Open App") {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // Quick Stats
            VStack(alignment: .leading, spacing: 4) {
                QuickStatRow(
                    title: "CPU",
                    value: "\(Int(SystemMonitor.shared.cpuUsage))%",
                    color: .blue
                )
                
                QuickStatRow(
                    title: "Memory",
                    value: "\(Int(SystemMonitor.shared.memoryUsage))%",
                    color: .green
                )
                
                QuickStatRow(
                    title: "Disk",
                    value: "\(Int(SystemMonitor.shared.diskUsage))%",
                    color: .orange
                )
                
                if SystemMonitor.shared.batteryLevel > 0 {
                    QuickStatRow(
                        title: "Battery",
                        value: "\(Int(SystemMonitor.shared.batteryLevel))%",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Actions
            VStack(spacing: 4) {
                Button("Show Dashboard") {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Quit Coreveo") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 200)
        .onAppear {
            SystemMonitor.shared.startMonitoring()
        }
    }
}

struct QuickStatRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    MenuBarView()
}
