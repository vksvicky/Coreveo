import Foundation

/// Development-only preview data helpers used by SwiftUI previews.
/// Files are stored under `Coreveo/Preview Content` and are not shipped in release builds.
enum PreviewData {
    static func loadJSON(named name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Preview Content") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}
// This folder is required by Xcode for SwiftUI previews
