import SwiftUI
import AppKit
import ApplicationServices
import SystemConfiguration
import Darwin

// Helper function to get the real user home directory
private func getRealHomeDirectory() -> String? {
    // Try multiple methods to get the real home directory
    
    // Method 1: Environment variable (most reliable for sandboxed apps)
    if let homeFromEnv = ProcessInfo.processInfo.environment["HOME"] {
        NSLog("[Onboarding] Got home from environment: \(homeFromEnv)")
        return homeFromEnv
    }
    
    // Method 2: getpwuid (fallback)
    let uid = getuid()
    if let pw = getpwuid(uid),
       let homeDir = pw.pointee.pw_dir {
        let homeFromPwuid = String(cString: homeDir)
        NSLog("[Onboarding] Got home from getpwuid: \(homeFromPwuid)")
        return homeFromPwuid
    }
    
    NSLog("[Onboarding] ⚠️ Could not determine real home directory")
    return nil
}

struct PermissionsOnboardingView: View {
    @Binding var showMainApp: Bool
    @State private var currentStep = 0
    @State private var accessibilityGranted = false
    @State private var fullDiskAccessGranted = false
    @State private var networkAccessGranted = false
    @State private var isChecking = false
    
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
                "Click 'Request Permission' button below",
                "Grant access in the system dialog",
                "Or manually go to System Settings",
                "Privacy & Security → Accessibility",
                "Add Coreveo to the list"
            ]
        ),
        PermissionItem(
            title: "Full Disk Access",
            description: "Required for disk monitoring and S.M.A.R.T. data",
            icon: "externaldrive.fill",
            color: .orange,
            instructions: [
                "Open System Settings",
                "Go to Privacy & Security",
                "Select Full Disk Access",
                "Click the + button",
                "Add Coreveo to the list"
            ]
        ),
        PermissionItem(
            title: "Network Monitoring",
            description: "Optional for advanced network monitoring features",
            icon: "network",
            color: .purple,
            instructions: [
                "This permission is optional for basic system monitoring",
                "Only required if you want advanced network features",
                "You can skip this step and enable later if needed",
                "Basic CPU, Memory, and Disk monitoring works without this"
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
                        isChecking: isChecking,
                        networkNotRequired: networkPermissionNotRequired(),
                        accessibilityGranted: $accessibilityGranted,
                        onCheckPermission: {
                            // Allow TCC to settle; update on main thread, and retry briefly
                            isChecking = true
                            pollPermission(step: currentStep, attempts: 8, interval: 0.5) {
                                isChecking = false
                            }
                        },
                        onOpenSystemSettings: {
                            openSystemSettings()
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
                        showMainApp = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Continue") {
                        if currentStep < permissions.count - 1 {
                            currentStep += 1
                        } else {
                            showMainApp = true
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
        // Refresh statuses when the app returns to foreground from System Settings
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkAllPermissions()
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

    /// Poll a specific permission a fixed number of times to catch updates without relaunch
    private func pollPermission(step: Int, attempts: Int, interval: TimeInterval, completion: @escaping () -> Void) {
        guard attempts > 0 else { completion(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            checkPermissionStatus(for: step)
            let grantedNow = getPermissionStatus(for: step)
            if grantedNow {
                completion()
            } else {
                pollPermission(step: step, attempts: attempts - 1, interval: interval, completion: completion)
            }
        }
    }
    
    private func checkAllPermissions() {
        accessibilityGranted = checkAccessibilityPermission()
        fullDiskAccessGranted = checkFullDiskAccessPermission()
        networkAccessGranted = checkNetworkPermission()
    }
    
    private func openSystemSettings() {
        // Always bring our app to front before prompting/opening settings
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }

        switch currentStep {
        case 0:
            // Accessibility: Show system prompt when explicitly requested
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            // Also open the System Settings pane to guide the user
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
                bringSystemSettingsToFront()
            }

            // Start polling to reflect the change as soon as it is granted
            isChecking = true
            pollPermission(step: 0, attempts: 20, interval: 0.5) {
                isChecking = false
            }

        case 1:
            // Full Disk Access pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
                bringSystemSettingsToFront()
            } else if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(fallback)
                bringSystemSettingsToFront()
            }

        case 2:
            // Network Extensions pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_NetworkExtensions") {
                NSWorkspace.shared.open(url)
                bringSystemSettingsToFront()
            } else if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(fallback)
                bringSystemSettingsToFront()
            }

            // Re-check status after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkPermissionStatus(for: 2)
            }

        default:
            break
        }
    }

    private func bringSystemSettingsToFront() {
        // Give System Settings a brief moment to launch/open the pane
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let candidateBundleIds = [
                "com.apple.systempreferences", // Most macOS versions
                "com.apple.systemsettings"     // Fallback (some reports for Ventura+)
            ]

            for bundleId in candidateBundleIds {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                    let activated = app.activate(options: [])
                    NSLog("[Onboarding] Activated System Settings (\(bundleId)): \(activated)")
                    if activated { return }
                }
            }
            NSLog("[Onboarding] System Settings activation attempt completed (may already be foreground)")
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        // For sandboxed apps, AXIsProcessTrustedWithOptions often returns false even when granted
        // Try multiple methods to detect Accessibility permission
        
        // Method 1: Standard check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSLog("[Onboarding] Accessibility standard check: \(isTrusted)")
        
        if isTrusted {
            return true
        }
        
        // Method 2: Try to create an accessibility element (works in sandboxed apps when granted)
        let appElement = AXUIElementCreateApplication(NSRunningApplication.current.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &value)
        if result == .success {
            NSLog("[Onboarding] Accessibility element creation: SUCCESS")
            return true
        } else {
            NSLog("[Onboarding] Accessibility element creation: FAILED (\(result.rawValue))")
        }
        
        // Method 2b: System-wide element capability check
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let systemWideResult = AXUIElementCopyAttributeValue(systemWideElement,
                                                             kAXFocusedApplicationAttribute as CFString,
                                                             &focusedApp)
        if systemWideResult == .success {
            NSLog("[Onboarding] Accessibility system-wide focused app: SUCCESS")
            return true
        } else {
            NSLog("[Onboarding] Accessibility system-wide check failed (code \(systemWideResult.rawValue))")
        }
        
        // Method 3: Check if we can access window information
        if let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) {
            let windows = windowList as? [[String: Any]] ?? []
            NSLog("[Onboarding] Accessibility window access: \(windows.count) windows visible")
            // If we can see window info, we likely have accessibility
            if windows.count > 0 {
                return true
            }
        }
        
        NSLog("[Onboarding] Accessibility check result: false (all methods)")
        return false
    }
    
    private func checkFullDiskAccessPermission() -> Bool {
        NSLog("[Onboarding] Checking Full Disk Access...")
        
        let fileManager = FileManager.default
        
        // Get the REAL user home directory using getpwuid (not the sandboxed one)
        guard let realHome = getRealHomeDirectory() else {
            NSLog("[Onboarding] ⚠️ Could not determine real home directory")
            return false
        }
        
        NSLog("[Onboarding] Real home directory: \(realHome)")
        NSLog("[Onboarding] Sandbox home directory: \(NSHomeDirectory())")
        
        // Test multiple protected paths - only need one to succeed
        let protectedPaths = [
            "\(realHome)/Library/Mail",                    // Mail data - requires FDA
            "\(realHome)/Library/Safari",                  // Safari data - requires FDA
            "\(realHome)/Library/Calendars",               // Calendar data - requires FDA
            "\(realHome)/Library/Application Support/com.apple.sharedfilelist", // Shared file lists - requires FDA
            "\(realHome)/Library/Keychains"                // Keychains - requires FDA (fallback)
        ]
        
        for path in protectedPaths {
            NSLog("[Onboarding] Testing FDA path: \(path)")
            
            // Check if path exists first
            guard fileManager.fileExists(atPath: path) else {
                NSLog("[Onboarding]   Path doesn't exist (skipping)")
                continue
            }
            
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                NSLog("[Onboarding] ✅ Full Disk Access GRANTED - accessed \(path) (\(contents.count) items)")
                return true
            } catch let error as NSError {
                NSLog("[Onboarding]   ❌ Access denied: \(error.domain) code:\(error.code) - \(error.localizedDescription)")
                
                // Check for specific permission denied errors
                if error.domain == NSCocoaErrorDomain && (error.code == 257 || error.code == 513) {
                    NSLog("[Onboarding]   This is a permission denied error (expected without FDA)")
                }
            }
        }
        
        NSLog("[Onboarding] ❌ Full Disk Access NOT GRANTED - could not access any protected paths")
        return false
    }
    
    private func checkNetworkPermission() -> Bool {
        // If the app does NOT bundle any Network Extension (app extensions or system extensions),
        // then no special permission is required on macOS 14+ for basic network monitoring.
        // In that case, treat as granted so the user is not blocked unnecessarily.

        let fileManager = FileManager.default
        var hasNetworkExtensions = false

        // Check for built-in app extensions (e.g., Packet Tunnel, Content Filter, etc.)
        if let pluginsURL = Bundle.main.builtInPlugInsURL,
           let pluginItems = try? fileManager.contentsOfDirectory(at: pluginsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            if pluginItems.contains(where: { $0.pathExtension == "appex" }) {
                hasNetworkExtensions = true
            }
        }

        // Check for system extensions inside the app bundle
        let systemExtensionsPath = (Bundle.main.bundlePath as NSString).appendingPathComponent("Contents/Library/SystemExtensions")
        if fileManager.fileExists(atPath: systemExtensionsPath) {
            hasNetworkExtensions = true
        }

        // If we don't ship any NE components, permission is not applicable → treat as granted
        if !hasNetworkExtensions {
            return true
        }

        // If we do ship NE components, we cannot reliably query enablement state without
        // using the specific NE APIs and entitlements. Guide user to enable it in Settings.
        return false
    }

    private func networkPermissionNotRequired() -> Bool {
        // Mirrors the logic in checkNetworkPermission that decides if NE components exist
        let fileManager = FileManager.default
        var hasNetworkExtensions = false

        if let pluginsURL = Bundle.main.builtInPlugInsURL,
           let pluginItems = try? fileManager.contentsOfDirectory(at: pluginsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            if pluginItems.contains(where: { $0.pathExtension == "appex" }) {
                hasNetworkExtensions = true
            }
        }

        let systemExtensionsPath = (Bundle.main.bundlePath as NSString).appendingPathComponent("Contents/Library/SystemExtensions")
        if fileManager.fileExists(atPath: systemExtensionsPath) {
            hasNetworkExtensions = true
        }

        return !hasNetworkExtensions
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
    let isChecking: Bool
    let networkNotRequired: Bool
    @Binding var accessibilityGranted: Bool
    let onCheckPermission: () -> Void
    let onOpenSystemSettings: () -> Void
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
                            
                            Text((currentStep == 2 && networkNotRequired) ? "Not Required" : (isGranted ? "Permission Granted" : "Permission Required"))
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
                        Button(action: { onCheckPermission() }) {
                            HStack(spacing: 8) {
                                if isChecking { ProgressView().scaleEffect(0.8) }
                                Text("Check Again")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(isChecking)
                        
                        if !isGranted {
                            Button(currentStep == 0 ? "Request Permission" : "Open System Settings") {
                                onOpenSystemSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        
                        // Add manual override for Accessibility when detection fails
                        if currentStep == 0 && !isGranted {
                            Button("I've Granted Permission") {
                                // Manual override - mark as granted
                                accessibilityGranted = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .font(.caption)
                        }
                    }
                }
                .frame(height: geometry.size.height * 0.2)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    PermissionsOnboardingView(showMainApp: .constant(false))
}
