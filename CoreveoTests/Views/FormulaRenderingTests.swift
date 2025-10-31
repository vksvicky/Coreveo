import XCTest

final class FormulaRenderingTests: XCTestCase {
    private func loadHelpMarkdown() throws -> String {
        let bundle = Bundle(for: Self.self)
        // In tests the file is copied into the app bundle resources; read from project path as fallback
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // CoreveoTests
            .appendingPathComponent("../docs/HELP.md").standardized
        if let data = try? Data(contentsOf: projectPath), let content = String(data: data, encoding: .utf8) {
            return content
        }
        XCTFail("Unable to load HELP.md from project path: \(projectPath.path)")
        return ""
    }

    func testHelpContainsDollarMathForUsageAndEquivalent() throws {
        let md = try loadHelpMarkdown()
        XCTAssertTrue(md.contains("$usage = (Δuser + Δsystem + Δnice) / Δtotal$"), "Usage fraction should be wrapped in $...$")
        XCTAssertTrue(md.contains("$usage = 1 − (Δidle / Δtotal)$"), "Equivalent fraction should be wrapped in $...$")
    }

    func testHelpContainsDollarMathForPeakCore() throws {
        let md = try loadHelpMarkdown()
        XCTAssertTrue(md.contains("$i_peak = arg max_i (usage_i)$"), "Peak core formula should be wrapped in $...$")
    }

    func testNonMathTextIsNotMarkedAsMath() throws {
        let md = try loadHelpMarkdown()
        XCTAssertTrue(md.contains("Light / Dark."), "Non-math slash should remain as text")
        XCTAssertTrue(md.contains("host_processor_info"), "Underscore identifier should remain as text")
        XCTAssertFalse(md.contains("$Light / Dark.$"))
        XCTAssertFalse(md.contains("$host_processor_info$"))
    }
}
