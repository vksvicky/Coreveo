import SwiftUI

struct ContentView: View {
    @StateObject private var systemMonitor = SystemMonitor()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }
                    .tag(0)
                
                CPUView()
                    .tabItem {
                        Label("CPU", systemImage: "cpu.fill")
                    }
                    .tag(1)
                
                MemoryView()
                    .tabItem {
                        Label("Memory", systemImage: "memorychip.fill")
                    }
                    .tag(2)
                
                DiskView()
                    .tabItem {
                        Label("Disk", systemImage: "externaldrive.fill")
                    }
                    .tag(3)
                
                NetworkView()
                    .tabItem {
                        Label("Network", systemImage: "network")
                    }
                    .tag(4)
                
                BatteryView()
                    .tabItem {
                        Label("Battery", systemImage: "battery.100")
                    }
                    .tag(5)
                
                TemperatureView()
                    .tabItem {
                        Label("Temperature", systemImage: "thermometer")
                    }
                    .tag(6)
                
                ProcessView()
                    .tabItem {
                        Label("Processes", systemImage: "list.bullet")
                    }
                    .tag(7)
            }
        }
        .environmentObject(systemMonitor)
        .onAppear {
            systemMonitor.startMonitoring()
        }
        .onDisappear {
            systemMonitor.stopMonitoring()
        }
    }
}

#Preview {
    ContentView()
}
