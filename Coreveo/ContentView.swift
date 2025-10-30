import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            TabView(selection: $selectedTab) {
                createDashboardTab()
                createCPUTab()
                createMemoryTab()
                createDiskTab()
                createNetworkTab()
                createBatteryTab()
                createTemperatureTab()
                createProcessTab()
            }
        }
        .onAppear {
            SystemMonitor.shared.startMonitoring()
        }
        .onDisappear {
            SystemMonitor.shared.stopMonitoring()
        }
    }
    
    @ViewBuilder
    private func createDashboardTab() -> some View {
        DashboardView(selectedTab: $selectedTab)
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar.fill")
            }
            .tag(0)
    }
    
    @ViewBuilder
    private func createCPUTab() -> some View {
        CPUView()
            .tabItem {
                Label("CPU", systemImage: "cpu.fill")
            }
            .tag(1)
    }
    
    @ViewBuilder
    private func createMemoryTab() -> some View {
        MemoryView()
            .tabItem {
                Label("Memory", systemImage: "memorychip.fill")
            }
            .tag(2)
    }
    
    @ViewBuilder
    private func createDiskTab() -> some View {
        DiskView()
            .tabItem {
                Label("Disk", systemImage: "externaldrive.fill")
            }
            .tag(3)
    }
    
    @ViewBuilder
    private func createNetworkTab() -> some View {
        NetworkView()
            .tabItem {
                Label("Network", systemImage: "network")
            }
            .tag(4)
    }
    
    @ViewBuilder
    private func createBatteryTab() -> some View {
        BatteryView()
            .tabItem {
                Label("Battery", systemImage: "battery.100")
            }
            .tag(5)
    }
    
    @ViewBuilder
    private func createTemperatureTab() -> some View {
        TemperatureView()
            .tabItem {
                Label("Temperature", systemImage: "thermometer")
            }
            .tag(6)
    }
    
    @ViewBuilder
    private func createProcessTab() -> some View {
        ProcessView()
            .tabItem {
                Label("Processes", systemImage: "list.bullet")
            }
            .tag(7)
    }
}

#Preview {
    ContentView()
}
