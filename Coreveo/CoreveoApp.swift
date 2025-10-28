import AppKit
import SwiftUI

@main
struct CoreveoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showOnboarding = true
    
    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                PermissionsOnboardingView(showMainApp: $showOnboarding)
                    .onAppear {
                        checkIfOnboardingNeeded()
                    }
            } else {
                ContentView()
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        // Menu bar app
        MenuBarExtra("Coreveo", systemImage: "chart.line.uptrend.xyaxis") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
    
    private func checkIfOnboardingNeeded() {
        // Check if user has completed onboarding before
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // For testing: Hold Shift key to reset onboarding
        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
        if isShiftPressed {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        
        if hasCompletedOnboarding {
            showOnboarding = false
        } else {
            // Show onboarding for first-time users
            showOnboarding = true
        }
    }
}

/// App delegate for handling macOS-specific functionality
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as regular app (not menu bar only)
        NSApp.setActivationPolicy(.regular)
        
        // Request necessary permissions
        requestPermissions()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true // Quit app when all windows are closed
    }
    
    private func requestPermissions() {
        // Check accessibility permissions without prompting
        // The onboarding screen will handle the permission request flow
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            NSLog("Accessibility permissions not yet granted - will be handled by onboarding")
        }
    }
}
