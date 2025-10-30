import Foundation

/// Pure calculator for per-core CPU usage based on tick snapshots.
/// Input arrays contain per-core arrays in order: [user, system, idle, nice].
enum CPUMetricsCalculator {
    static func computePerCoreUsage(previous: [[UInt64]], current: [[UInt64]]) -> [Double] {
        let coreCount = min(previous.count, current.count)
        guard coreCount > 0 else { return [] }
        var results: [Double] = []
        results.reserveCapacity(coreCount)

        for coreIndex in 0..<coreCount {
            let prevTicks = previous[coreIndex]
            let currTicks = current[coreIndex]
            // Safely index; if malformed, treat as zero deltas
            let deltaUser = delta(prevTicks, currTicks, 0)
            let deltaSystem = delta(prevTicks, currTicks, 1)
            let deltaIdle = delta(prevTicks, currTicks, 2)
            let deltaNice = delta(prevTicks, currTicks, 3)
            let total = Double(deltaUser + deltaSystem + deltaIdle + deltaNice)
            if total <= 0 {
                results.append(0.0)
                continue
            }
            let active = Double(deltaUser + deltaSystem + deltaNice)
            results.append(active / total)
        }
        return results
    }

    private static func delta(_ prev: [UInt64], _ curr: [UInt64], _ idx: Int) -> UInt64 {
        guard prev.count > idx, curr.count > idx else { return 0 }
        let pv = prev[idx]
        let cv = curr[idx]
        return cv >= pv ? (cv - pv) : 0
    }
}
