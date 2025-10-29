import AppKit
import SwiftUI

/// Individual settings section in sidebar
struct SettingsSection: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 28, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Feature row component
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

/// Individual permission row view
struct PermissionRowView: View {
    let title: String
    let description: String
    let icon: String
    let isGranted: Bool
    let onRequest: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isGranted ? .green : .orange)
                        .font(.title3)
                    
                    Text(isGranted ? "Granted" : "Not Granted")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isGranted ? .green : .orange)
                }
            }
            
            if !isGranted {
                HStack(spacing: 12) {
                    Button("Request Permission") {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Open System Settings") {
                        onOpenSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                Button("Open System Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("You can revoke this permission in System Settings")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
