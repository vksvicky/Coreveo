import SwiftUI

/// Main settings view for the application
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(selection: $selectedTab) {
                SettingsSection(
                    icon: "paintbrush",
                    title: "Appearance",
                    subtitle: "Theme and visual settings"
                ) {
                    selectedTab = 0
                }
                .tag(0)
                
                SettingsSection(
                    icon: "gear",
                    title: "General",
                    subtitle: "General app preferences"
                ) {
                    selectedTab = 1
                }
                .tag(1)
                
                SettingsSection(
                    icon: "lock.shield",
                    title: "Permissions",
                    subtitle: "System permissions status"
                ) {
                    selectedTab = 2
                }
                .tag(2)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 220, idealWidth: 240, maxWidth: 260)
            
            // Main content
            Group {
                switch selectedTab {
                case 0:
                    AppearanceSettingsView()
                case 1:
                    GeneralSettingsView()
                case 2:
                    PermissionsSettingsView()
                default:
                    AppearanceSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Settings")
        .frame(minWidth: 700, minHeight: 480)
    }
}

#Preview {
    SettingsView()
}
