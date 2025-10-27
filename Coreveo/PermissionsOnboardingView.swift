import SwiftUI
import AppKit
import ApplicationServices

struct PermissionsOnboardingView: View {
    @Binding var showMainApp: Bool
    @State private var currentStep = 0
    @State private var accessibilityGranted = false
    @State private var fullDiskAccessGranted = false
    @State private var networkAccessGranted = false
    
    // Helper function to load app icon
    private var appIcon: NSImage? {
        // Method 1: Get the app's own icon from NSWorkspace (most reliable)
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        
        // Method 2: Try loading from asset catalog
        if let icon = NSImage(named: NSImage.Name("AppIcon")) {
            return icon
        }
        
        // Method 3: Try loading Coreveo.png from Coreveo_Coreveo.bundle (SPM build)
        if let resourcePath = Bundle.main.resourcePath {
            let bundlePath = "\(resourcePath)/Coreveo_Coreveo.bundle"
            if FileManager.default.fileExists(atPath: bundlePath),
               let resourceBundle = Bundle(path: bundlePath) {
                if let iconPath = resourceBundle.path(forResource: "Coreveo", ofType: "png") {
                    if let icon = NSImage(contentsOfFile: iconPath) {
                        return icon
                    }
                }
            }
        }
        
        // Method 3b: Try loading Coreveo.png directly from Resources
        if let resourcePath = Bundle.main.resourcePath {
            let iconPath = "\(resourcePath)/Coreveo.png"
            if let icon = NSImage(contentsOfFile: iconPath) {
                return icon
            }
        }
        
        // Method 4: Try using the running app's icon
        if let appIcon = NSApp.applicationIconImage {
            return appIcon
        }
        
        // Method 5: Create a simple programmatic icon as final fallback
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Draw a simple gradient background
        let gradient = NSGradient(colors: [NSColor.systemBlue, NSColor.systemPurple])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        // Draw "C" text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let text = NSAttributedString(string: "C", attributes: attributes)
        let textSize = text.size()
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect)
        
        image.unlockFocus()
        return image
    }
    
    private let permissions = [
        PermissionItem(
            title: "Accessibility Permission",
            description: "Required for process monitoring and system control",
            icon: "person.crop.circle",
            color: .blue,
            instructions: [
                "1. Click 'Request Permission' button below",
                "2. Grant access in the system dialog",
                "3. Or manually go to System Settings",
                "4. Privacy & Security → Accessibility",
                "5. Add Coreveo to the list"
            ]
        ),
        PermissionItem(
            title: "Full Disk Access",
            description: "Required for disk monitoring and S.M.A.R.T. data",
            icon: "externaldrive.fill",
            color: .orange,
            instructions: [
                "1. Open System Settings",
                "2. Go to Privacy & Security",
                "3. Select Full Disk Access",
                "4. Click the + button",
                "5. Add Coreveo to the list"
            ]
        ),
        PermissionItem(
            title: "Network Monitoring",
            description: "Required for network speed and security monitoring",
            icon: "network",
            color: .purple,
            instructions: [
                "1. Open System Settings",
                "2. Go to Privacy & Security",
                "3. Select Network Extensions",
                "4. Click the + button",
                "5. Add Coreveo to the list"
            ]
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header - Static position
            VStack(spacing: 16) {
                // Use the custom app icon with fallback
                if let image = appIcon {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                } else {
                    // Fallback icon if AppIcon not found
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                }
                
                Text("Welcome to Coreveo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("To provide comprehensive system monitoring, Coreveo needs a few permissions")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            // Progress indicator - Static position
            HStack(spacing: 8) {
                ForEach(0..<permissions.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .onTapGesture {
                            currentStep = index
                        }
                }
            }
            .padding(.bottom, 20)
            
            // Main content area - use full window space
            VStack(spacing: 0) {
                // Permission content - takes up most of the space
                if currentStep < permissions.count {
                    PermissionStepView(
                        permission: permissions[currentStep],
                        isGranted: getPermissionStatus(for: currentStep),
                        currentStep: currentStep,
                        onCheckPermission: {
                            checkPermissionStatus(for: currentStep)
                        },
                        onNext: {
                            if currentStep < permissions.count - 1 {
                                currentStep += 1
                            } else {
                                showMainApp = false
                            }
                        },
                        onSkip: {
                            if currentStep < permissions.count - 1 {
                                currentStep += 1
                            } else {
                                showMainApp = false
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 20)
            
            // Fixed Footer - Static position
            VStack(spacing: 12) {
                Text("You can change these permissions later in System Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Button("Skip All") {
                        showMainApp = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Continue") {
                        if currentStep < permissions.count - 1 {
                            currentStep += 1
                        } else {
                            showMainApp = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.bottom, 30)
        }
        .frame(width: 700, height: 600) // Clean, reasonable size
        .background(Color.clear)
        .onAppear {
            checkAllPermissions()
            // Bring window to front
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onChange(of: showMainApp) {
            if showMainApp {
                // Mark onboarding as completed
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold {
                        // Swipe right - go to previous step
                        if currentStep > 0 {
                            currentStep -= 1
                        }
                    } else if value.translation.width < -threshold {
                        // Swipe left - go to next step
                        if currentStep < permissions.count - 1 {
                            currentStep += 1
                        } else {
                            showMainApp = false
                        }
                    }
                }
        )
        .onKeyPress(.leftArrow) {
            // Previous step
            if currentStep > 0 {
                currentStep -= 1
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            // Next step
            if currentStep < permissions.count - 1 {
                currentStep += 1
            } else {
                showMainApp = false
            }
            return .handled
        }
        .onKeyPress(.escape) {
            // Skip all
            showMainApp = false
            return .handled
        }
    }
    
    private func getPermissionStatus(for step: Int) -> Bool {
        switch step {
        case 0: return accessibilityGranted
        case 1: return fullDiskAccessGranted
        case 2: return networkAccessGranted
        default: return false
        }
    }
    
    private func checkPermissionStatus(for step: Int) {
        switch step {
        case 0:
            accessibilityGranted = checkAccessibilityPermission()
        case 1:
            fullDiskAccessGranted = checkFullDiskAccessPermission()
        case 2:
            networkAccessGranted = checkNetworkPermission()
        default:
            break
        }
    }
    
    private func checkAllPermissions() {
        accessibilityGranted = checkAccessibilityPermission()
        fullDiskAccessGranted = checkFullDiskAccessPermission()
        networkAccessGranted = checkNetworkPermission()
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func checkFullDiskAccessPermission() -> Bool {
        // Check if we can access system files - this is a simplified check
        // In reality, Full Disk Access is harder to detect programmatically
        return false // Default to false since we can't reliably detect it
    }
    
    private func checkNetworkPermission() -> Bool {
        // Network permissions are typically not required for basic network monitoring
        // This is more about network extensions which we're not using
        return false // Default to false - user must manually grant if needed
    }
}

struct PermissionItem {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let instructions: [String]
}

struct PermissionStepView: View {
    let permission: PermissionItem
    let isGranted: Bool
    let currentStep: Int
    let onCheckPermission: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Middle section - Side by side layout
                HStack(spacing: 24) {
                    // Part 1: Permission icon and info (Left side)
                    VStack(spacing: 12) {
                        // Permission icon
                        ZStack {
                            Circle()
                                .fill(permission.color.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: permission.icon)
                                .font(.system(size: 32))
                                .foregroundColor(permission.color)
                        }
                        
                        VStack(spacing: 6) {
                            Text(permission.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(permission.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Status indicator
                        HStack(spacing: 6) {
                            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isGranted ? .green : .orange)
                                .font(.title3)
                            
                            Text(isGranted ? "Permission Granted" : "Permission Required")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(isGranted ? .green : .orange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Part 2: Instructions (Right side, only if not granted)
                    if !isGranted {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("How to grant this permission:")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(permission.instructions.indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .frame(width: 20, alignment: .leading)
                                        
                                        Text(permission.instructions[index])
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: geometry.size.height * 0.65)
                
                // Add spacing between content and buttons
                Spacer()
                    .frame(height: 28)
                
                // Bottom section - Action buttons
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button("Check Again") {
                            onCheckPermission()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        if !isGranted {
                            Button(currentStep == 0 ? "Request Permission" : "Open System Settings") {
                                openSystemSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                }
                .frame(height: geometry.size.height * 0.2)
            }
            .padding(.horizontal, 32)
        }
    }
    
    private func openSystemSettings() {
        // For accessibility, we need to trigger the system dialog
        if currentStep == 0 {
            // Trigger accessibility permission request
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        } else {
            // For other permissions, open System Settings
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    PermissionsOnboardingView(showMainApp: .constant(false))
}
