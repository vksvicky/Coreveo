@testable import Coreveo
import SwiftUI
import XCTest

/// Tests to verify CPU view layout adapts correctly to various core counts (2025-2026)
/// 
/// Current Apple Silicon (2025) - Source: https://www.apple.com/uk/mac/compare/
/// - M5: 10-14 cores (MacBook Pro 14")
/// - M4: 8-10 cores (MacBook Air, iMac, Mac mini)
/// - M4 Pro: 14-20 cores (MacBook Pro, Mac mini)
/// - M4 Max: 16-40 cores (MacBook Pro 16", Mac Studio M4 Max)
/// - M3 Ultra: 60-80 cores (Mac Studio) ⭐ **80 cores = CURRENT MAXIMUM**
/// - M2 Ultra: 60-76 cores (Mac Pro 2023, legacy)
///
/// Legacy Intel (still supported):
/// - Mac Pro 2019: up to 28 cores (Intel Xeon W)
/// - iMac Pro: up to 18 cores
///
/// Future-proofing: Testing up to 256 cores for upcoming generations
final class CPULayoutTests: XCTestCase {
    // MARK: - Grid Layout Tests
    
    func testGridLayoutFor1Core() throws {
        // Given: Single core CPU (rare but possible in VMs)
        let coreUsages: [Double] = [0.45]
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 1 column
        XCTAssertEqual(grid.columnCount, 1, "1 core should use 1 column")
    }
    
    func testGridLayoutFor4Cores() throws {
        // Given: Entry-level MacBook Air M1/M2 (4 performance cores shown)
        let coreUsages: [Double] = [0.3, 0.4, 0.5, 0.2]
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 1 column for easy viewing
        XCTAssertEqual(grid.columnCount, 1, "4 cores should use 1 column")
    }
    
    func testGridLayoutFor8Cores() throws {
        // Given: MacBook Pro M1/M2 Pro (8 cores total)
        let coreUsages: [Double] = [0.6, 0.5, 0.4, 0.7, 0.3, 0.2, 0.8, 0.5]
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 2 columns
        XCTAssertEqual(grid.columnCount, 2, "8 cores should use 2 columns")
    }
    
    func testGridLayoutFor12Cores() throws {
        // Given: M2 Pro/Max (12 cores)
        let coreUsages = Array(repeating: 0.5, count: 12)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 3 columns
        XCTAssertEqual(grid.columnCount, 3, "12 cores should use 3 columns")
    }
    
    func testGridLayoutFor16Cores() throws {
        // Given: Mac Studio M1 Max (16 cores: 10P + 2E shown as 16 logical)
        let coreUsages = Array(repeating: 0.5, count: 16)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 3 columns
        XCTAssertEqual(grid.columnCount, 3, "16 cores should use 3 columns")
    }
    
    func testGridLayoutFor24Cores() throws {
        // Given: M3 Max / Mac Studio M2 Ultra (24 cores)
        let coreUsages = Array(repeating: 0.5, count: 24)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 4 columns
        XCTAssertEqual(grid.columnCount, 4, "24 cores should use 4 columns")
    }
    
    func testGridLayoutFor40Cores() throws {
        // Given: M4 Max (40 cores configuration)
        let coreUsages = Array(repeating: 0.5, count: 40)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 6 columns
        XCTAssertEqual(grid.columnCount, 6, "40 cores should use 6 columns")
    }
    
    func testGridLayoutFor60Cores() throws {
        // Given: M3 Ultra base configuration (60 cores)
        let coreUsages = Array(repeating: 0.5, count: 60)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 6 columns
        XCTAssertEqual(grid.columnCount, 6, "60 cores should use 6 columns")
    }
    
    func testGridLayoutFor28Cores() throws {
        // Given: Mac Pro 2019 Intel Xeon (28 cores maximum)
        let coreUsages = Array(repeating: 0.5, count: 28)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 4 columns
        XCTAssertEqual(grid.columnCount, 4, "28 cores should use 4 columns")
    }
    
    func testGridLayoutFor32Cores() throws {
        // Given: High-end workstation (32 cores)
        let coreUsages = Array(repeating: 0.5, count: 32)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 4 columns
        XCTAssertEqual(grid.columnCount, 4, "32 cores should use 4 columns")
    }
    
    func testGridLayoutFor64Cores() throws {
        // Given: M3 Ultra or M4 Mac Studio (64 cores)
        let coreUsages = Array(repeating: 0.5, count: 64)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 6 columns for compact display
        XCTAssertEqual(grid.columnCount, 6, "64 cores should use 6 columns")
    }
    
    func testGridLayoutFor76Cores() throws {
        // Given: M2 Ultra (76 cores)
        let coreUsages = Array(repeating: 0.5, count: 76)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 8 columns for maximum density
        XCTAssertEqual(grid.columnCount, 8, "76 cores should use 8 columns")
    }
    
    func testGridLayoutFor80Cores() throws {
        // Given: M3 Ultra maximum configuration (80 cores) ⭐ Current production max
        let coreUsages = Array(repeating: 0.5, count: 80)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 8 columns for maximum density
        XCTAssertEqual(grid.columnCount, 8, "80 cores should use 8 columns")
    }
    
    func testGridLayoutFor128Cores() throws {
        // Given: M4 Mac Pro (2026) or future ultra-high-end workstation
        let coreUsages = Array(repeating: 0.5, count: 128)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 8 columns for maximum density
        XCTAssertEqual(grid.columnCount, 8, "128 cores should use 8 columns")
    }
    
    func testGridLayoutFor256Cores() throws {
        // Given: Future-proofing for extreme workstations (2027+)
        let coreUsages = Array(repeating: 0.5, count: 256)
        let grid = PerCoreUsageGrid(coreUsages: coreUsages)
        
        // Then: Should use 8 columns (max density)
        XCTAssertEqual(grid.columnCount, 8, "256 cores should use 8 columns")
    }
    
    // MARK: - Color Coding Tests
    
    func testCoreUsageColorGreen() throws {
        // Given: Low usage core
        let card = CoreUsageCard(coreNumber: 1, usage: 0.25)
        
        // Then: Should be green (idle/light load)
        XCTAssertEqual(card.usageColor, .green, "Usage < 30% should be green")
    }
    
    func testCoreUsageColorYellow() throws {
        // Given: Moderate usage core
        let card = CoreUsageCard(coreNumber: 1, usage: 0.45)
        
        // Then: Should be yellow (moderate load)
        XCTAssertEqual(card.usageColor, .yellow, "Usage 30-60% should be yellow")
    }
    
    func testCoreUsageColorOrange() throws {
        // Given: High usage core
        let card = CoreUsageCard(coreNumber: 1, usage: 0.70)
        
        // Then: Should be orange (high load)
        XCTAssertEqual(card.usageColor, .orange, "Usage 60-80% should be orange")
    }
    
    func testCoreUsageColorRed() throws {
        // Given: Very high usage core
        let card = CoreUsageCard(coreNumber: 1, usage: 0.95)
        
        // Then: Should be red (critical load)
        XCTAssertEqual(card.usageColor, .red, "Usage >= 80% should be red")
    }
    
    // MARK: - Active Core Detection Tests
    
    func testActiveCoreCounting() throws {
        // Given: Mixed usage across cores (some idle, some active)
        let usages: [Double] = [
            0.8,  // Active
            0.02, // Idle
            0.6,  // Active
            0.01, // Idle
            0.3,  // Active
            0.03, // Idle
            0.9,  // Active
            0.04  // Idle
        ]
        
        // When: Counting active cores (> 5% threshold)
        let activeCores = usages.filter { $0 > 0.05 }
        
        // Then: Should correctly identify 4 active cores
        XCTAssertEqual(activeCores.count, 4, "Should identify 4 cores above 5% threshold")
    }
    
    func testPeakCoreDetection() throws {
        // Given: Varied core usage
        let usages: [Double] = [0.3, 0.5, 0.9, 0.2, 0.7, 0.4]
        
        // When: Finding peak usage
        let peak = usages.max()
        
        // Then: Should identify 90% as peak
        XCTAssertEqual(peak, 0.9, "Should identify 0.9 (90%) as peak usage")
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testMacBookAirM2Scenario() throws {
        // Given: MacBook Air M2 with 8 cores (4P + 4E)
        // Typical light workload: efficiency cores idle, performance cores active
        let usages: [Double] = [
            0.45, 0.52, 0.38, 0.41, // Performance cores
            0.02, 0.01, 0.03, 0.02  // Efficiency cores (mostly idle)
        ]
        
        let grid = PerCoreUsageGrid(coreUsages: usages)
        let activeCores = usages.filter { $0 > 0.05 }.count
        
        // Then: Should use 2 columns and show 4 active cores
        XCTAssertEqual(grid.columnCount, 2)
        XCTAssertEqual(activeCores, 4, "Should show 4 active performance cores")
    }
    
    func testMacProIntelWorkloadScenario() throws {
        // Given: Mac Pro 2019 with 28 cores
        // Heavy parallel workload: all cores active
        let usages = Array(repeating: 0.75, count: 28)
        
        let grid = PerCoreUsageGrid(coreUsages: usages)
        let activeCores = usages.filter { $0 > 0.05 }.count
        let peak = usages.max()
        
        // Then: Should use 4 columns with all cores active
        XCTAssertEqual(grid.columnCount, 4)
        XCTAssertEqual(activeCores, 28, "All 28 cores should be active")
        XCTAssertEqual(peak, 0.75, "Peak should be 75%")
    }
    
    func testMacStudioM2UltraScenario() throws {
        // Given: Mac Studio M2 Ultra with 24 cores
        // Video rendering workload: high usage across most cores
        let usages: [Double] = Array(repeating: 0.85, count: 16) + // High usage cores
                                Array(repeating: 0.15, count: 8)   // Background task cores
        
        let grid = PerCoreUsageGrid(coreUsages: usages)
        let activeCores = usages.filter { $0 > 0.05 }.count
        let peak = usages.max()
        
        // Then: Should use 4 columns with most cores active
        XCTAssertEqual(grid.columnCount, 4)
        XCTAssertEqual(activeCores, 24, "All cores should be above threshold")
        XCTAssertEqual(peak, 0.85, "Peak should be 85%")
    }
    
    func testM4MaxScenario() throws {
        // Given: M4 Max with 40 cores (2025)
        // Machine learning workload: all cores heavily utilized
        let usages = Array(repeating: 0.92, count: 40)
        
        let grid = PerCoreUsageGrid(coreUsages: usages)
        let activeCores = usages.filter { $0 > 0.05 }.count
        let highLoadCores = usages.filter { $0 > 0.8 }.count
        
        // Then: Should use 6 columns with all cores at high load
        XCTAssertEqual(grid.columnCount, 6)
        XCTAssertEqual(activeCores, 40, "All 40 cores should be active")
        XCTAssertEqual(highLoadCores, 40, "All cores should be at high load")
    }
    
    func testM3UltraMaxScenario() throws {
        // Given: Mac Studio M3 Ultra with 80 cores (2025) ⭐ Current production max
        // Heavy video editing + effects rendering workload
        let usages = Array(repeating: 0.88, count: 80)
        
        let grid = PerCoreUsageGrid(coreUsages: usages)
        let activeCores = usages.filter { $0 > 0.05 }.count
        let highLoadCores = usages.filter { $0 > 0.8 }.count
        
        // Then: Should use 8 columns with all cores at high load
        XCTAssertEqual(grid.columnCount, 8)
        XCTAssertEqual(activeCores, 80, "All 80 cores should be active")
        XCTAssertEqual(highLoadCores, 80, "All cores should be at high load")
    }
    
    func testM4MacProFutureScenario() throws {
        // Given: Future M4 Mac Pro with 128 cores (2026)
        // Heavy parallel compilation workload
        let usages = Array(repeating: 0.78, count: 128)
        
        let grid = PerCoreUsageGrid(coreUsages: usages)
        let activeCores = usages.filter { $0 > 0.05 }.count
        
        // Then: Should use 8 columns with all cores active
        XCTAssertEqual(grid.columnCount, 8)
        XCTAssertEqual(activeCores, 128, "All 128 cores should be active")
    }
}
