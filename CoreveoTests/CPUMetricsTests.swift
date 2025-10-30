@testable import Coreveo
import XCTest

/// BDD-style tests for per-core CPU usage calculation
final class CPUMetricsTests: XCTestCase {
    func testPerCoreUsageFromTicks_simpleTwoCores() throws {
        // Given: previous and current tick snapshots for 2 cores
        // Ticks order: user, system, idle, nice
        let previous: [[UInt64]] = [
            [100, 50, 850, 0],  // core 0
            [200, 100, 700, 0]  // core 1
        ]
        let current: [[UInt64]] = [
            [150, 70, 880, 0],  // core 0 (adds 50 user, 20 system, 30 idle)
            [260, 130, 730, 0]  // core 1 (adds 60 user, 30 system, 30 idle)
        ]

        // When: computing per-core usage
        let usage = CPUMetricsCalculator.computePerCoreUsage(previous: previous, current: current)

        // Then: usage = (user+system+nice) / total
        // Core 0 deltas: user 50, system 20, idle 30 => total 100 => active 70% 
        // Core 1 deltas: user 60, system 30, idle 30 => total 120 => active 75%
        XCTAssertEqual(usage.count, 2)
        XCTAssertEqual(round(usage[0] * 100) / 100, 0.7, accuracy: 0.0001)
        XCTAssertEqual(round(usage[1] * 100) / 100, 0.75, accuracy: 0.0001)
    }

    func testPerCoreUsage_handlesMismatchedCountsSafely() throws {
        // Given: current has fewer cores than previous
        let previous: [[UInt64]] = [[10, 10, 80, 0], [20, 10, 70, 0]]
        let current: [[UInt64]] = [[20, 20, 60, 0]]

        // When
        let usage = CPUMetricsCalculator.computePerCoreUsage(previous: previous, current: current)

        // Then: calculates only overlapping cores
        XCTAssertEqual(usage.count, 1)
    }

    func testPerCoreUsage_guardsZeroTotalDelta() throws {
        // Given: no change in ticks
        let ticks: [[UInt64]] = [[100, 50, 850, 0]]

        // When
        let usage = CPUMetricsCalculator.computePerCoreUsage(previous: ticks, current: ticks)

        // Then
        XCTAssertEqual(usage, [0.0])
    }
}
