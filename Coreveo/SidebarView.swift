import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: Int
    
    private let menuItems = [
        MenuItem(title: "Dashboard", icon: "chart.bar.fill", tag: 0),
        MenuItem(title: "CPU", icon: "cpu.fill", tag: 1),
        MenuItem(title: "Memory", icon: "memorychip.fill", tag: 2),
        MenuItem(title: "Disk", icon: "externaldrive.fill", tag: 3),
        MenuItem(title: "Network", icon: "network", tag: 4),
        MenuItem(title: "Battery", icon: "battery.100", tag: 5),
        MenuItem(title: "Temperature", icon: "thermometer", tag: 6),
        MenuItem(title: "Processes", icon: "list.bullet", tag: 7)
    ]
    
    var body: some View {
        List(menuItems, id: \.tag) { item in
            Button(action: {
                selectedTab = item.tag
            }) {
                HStack {
                    Image(systemName: item.icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text(item.title)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == item.tag ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

struct MenuItem {
    let title: String
    let icon: String
    let tag: Int
}

#Preview {
    SidebarView(selectedTab: .constant(0))
}
