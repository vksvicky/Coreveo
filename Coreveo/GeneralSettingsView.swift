import SwiftUI

/// General settings tab
struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("startMonitoringOnLaunch") private var startMonitoringOnLaunch = true
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage("refreshIntervalSeconds") private var refreshIntervalSeconds = 1.0
    @AppStorage("useCelsius") private var useCelsius = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("General")
                        .font(.system(size: 34, weight: .bold))
                    
                    Text("General application preferences")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 24) {

                // Launch at Login
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at Login")
                            .font(.headline)
                        Text("Start Coreveo automatically when you sign in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                }
                
                // Start Monitoring on Launch
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Monitoring on Launch")
                            .font(.headline)
                        Text("Begin collecting system stats immediately")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    Toggle("", isOn: $startMonitoringOnLaunch)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                }
                
                // Show Menu Bar Item
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Menu Bar Item")
                            .font(.headline)
                        Text("Display summary stats in the menu bar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    Toggle("", isOn: $showMenuBarItem)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                }
                
                // Refresh Interval
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                    Text("Refresh Interval")
                        .font(.headline)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text("How often system stats update")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    HStack(spacing: 16) {
                        Slider(value: $refreshIntervalSeconds, in: 0.5...5.0, step: 0.5) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("0.5s").font(.caption)
                        } maximumValueLabel: {
                            Text("5s").font(.caption)
                        }
                        .frame(width: 180)
                        
                        Text("\(String(format: "%.1fs", refreshIntervalSeconds))")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                
                // Temperature Units
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                    Text("Temperature Units")
                        .font(.headline)
                    }
                    
                    Spacer()
                    Picker("", selection: $useCelsius) {
                        Text("Celsius").tag(true)
                        Text("Fahrenheit").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }
                
                Spacer(minLength: 20)
            }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
