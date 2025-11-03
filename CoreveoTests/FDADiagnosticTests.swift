@testable import Coreveo
import XCTest
import Darwin  // For getpwuid

/// Diagnostic tests to find what ACTUALLY requires FDA on M4 Macs
final class FDADiagnosticTests: XCTestCase {
    
    /// Get the real user home directory (not the sandboxed container)
    private func getRealHomeDirectory() -> String? {
        // Get username and construct the REAL path (not sandboxed)
        let uid = getuid()
        if let pw = getpwuid(uid),
           let username = pw.pointee.pw_name {
            let usernameString = String(cString: username)
            return "/Users/\(usernameString)"
        }
        return nil
    }
    
    @MainActor
    func testWhatRequiresFDA() {
        print("\n=== FDA Diagnostic Test (Disable FDA in System Settings first!) ===\n")
        
        let fileManager = FileManager.default
        let sandboxHome = NSHomeDirectory()
        
        guard let home = getRealHomeDirectory() else {
            XCTFail("Could not determine real home directory")
            return
        }
        
        // Detect system info
        print("System Information:")
        print("  Sandbox Home: \(sandboxHome)")
        print("  Real Home: \(home)")
        print("  Is Sandboxed: \(sandboxHome.contains("/Containers/"))")
        
        #if arch(arm64)
        print("  Architecture: Apple Silicon (ARM64)")
        #elseif arch(x86_64)
        print("  Architecture: Intel (x86_64)")
        #else
        print("  Architecture: Unknown")
        #endif
        
        if #available(macOS 14.0, *) {
            print("  macOS: 14.0+")
        } else {
            print("  macOS: < 14.0")
        }
        print("")
        
        // Test various paths to see which ones ACTUALLY require FDA
        let testPaths: [(path: String, description: String, priority: String)] = [
            // PRIMARY paths (most reliable across systems)
            ("\(home)/Library/Mail", "Mail directory", "PRIMARY"),
            ("\(home)/Library/Calendars", "Calendars directory", "PRIMARY"),
            ("\(home)/Library/Messages", "Messages directory", "PRIMARY"),
            
            // FALLBACK paths
            ("\(home)/Library/Safari", "Safari directory", "FALLBACK"),
            ("\(home)/Library/Safari/History.db", "Safari History DB", "FALLBACK"),
            ("\(home)/Library/Mail/V10/MailData/Envelope Index", "Mail Envelope Index", "FALLBACK"),
            ("\(home)/Library/Application Support/com.apple.TCC/TCC.db", "User TCC Database", "FALLBACK"),
            
            // System paths (may not require FDA on all systems)
            ("/Library/Application Support/com.apple.TCC/TCC.db", "System TCC Database", "SYSTEM"),
            ("/Library/Application Support", "System Application Support", "SYSTEM"),
            ("/private/var/db/", "System DB directory", "SYSTEM"),
        ]
        
        print("Testing paths (FDA should be DISABLED in System Settings):\n")
        
        var primaryPassed = 0
        var fallbackPassed = 0
        
        for test in testPaths {
            let result = testPath(test.path, description: test.description, priority: test.priority, fileManager: fileManager)
            if result && test.priority == "PRIMARY" {
                primaryPassed += 1
            } else if result && test.priority == "FALLBACK" {
                fallbackPassed += 1
            }
        }
        
        print("\n=== Analysis ===")
        print("PRIMARY paths requiring FDA: \(primaryPassed) (ideal: at least 1)")
        print("FALLBACK paths requiring FDA: \(fallbackPassed)")
        print("")
        print("Paths that returned 'ACCESSIBLE' should NOT be used for FDA detection")
        print("Paths that returned 'DENIED' ARE reliable for FDA detection")
        
        if primaryPassed > 0 {
            print("\n✅ System has reliable PRIMARY FDA detection paths")
        } else if fallbackPassed > 0 {
            print("\n⚠️  System only has FALLBACK FDA detection paths")
        } else {
            print("\n❌ WARNING: No reliable FDA detection paths found!")
        }
        
        print("\n========================================\n")
    }
    
    private func testPath(_ path: String, description: String, priority: String, fileManager: FileManager) -> Bool {
        let exists = fileManager.fileExists(atPath: path)
        
        if !exists {
            print("[\(priority)] ⚠️  \(description): DOES NOT EXIST")
            print("         Path: \(path)\n")
            return false
        }
        
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        
        do {
            if isDirectory.boolValue {
                // Try to list directory
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                print("[\(priority)] ❌ \(description): ACCESSIBLE (listed \(contents.count) items)")
                print("         Path: \(path)")
                print("         ⚠️  This path does NOT require FDA!\n")
                return false
            } else {
                // Try to read file attributes
                _ = try fileManager.attributesOfItem(atPath: path)
                print("[\(priority)] ❌ \(description): ACCESSIBLE (can read attributes)")
                print("         Path: \(path)")
                print("         ⚠️  This path does NOT require FDA!\n")
                return false
            }
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == 257 {
                print("[\(priority)] ✅ \(description): DENIED")
                print("         Path: \(path)")
                print("         ✓ This path REQUIRES FDA\n")
                return true
            } else {
                print("[\(priority)] ⚠️  \(description): ERROR (\(error.code))")
                print("         Path: \(path)")
                print("         Error: \(error.localizedDescription)\n")
                return false
            }
        }
    }
}

