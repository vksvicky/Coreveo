@testable import Coreveo
import XCTest

final class SystemMonitorCPUTests: XCTestCase {
    @MainActor
    func testApplyPerCoreTicksSnapshotPublishesUsage() async throws {
        // Given
        let monitor = SystemMonitor.shared
        let prev: [[UInt64]] = [[100, 50, 850, 0], [200, 100, 700, 0]]
        let curr: [[UInt64]] = [[150, 70, 880, 0], [260, 130, 730, 0]]

        // When: first snapshot sets baseline
        await monitor.applyPerCoreTicksSnapshot(prev)
        // When: second snapshot computes usage
        await monitor.applyPerCoreTicksSnapshot(curr)

        // Then
        XCTAssertEqual(monitor.perCoreUsage.count, 2)
        XCTAssertEqual(round(monitor.perCoreUsage[0] * 100) / 100, 0.7, accuracy: 0.0001)
        XCTAssertEqual(round(monitor.perCoreUsage[1] * 100) / 100, 0.75, accuracy: 0.0001)
    }
}
