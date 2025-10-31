import Foundation

protocol TemperatureProviding {
    /// Returns CPU temperature in Celsius for a given current CPU usage hint.
    func cpuTemperatureC(currentCPUUsage: Double) -> Double?
}

protocol TemperatureSensorsProviding {
    /// Returns map of sensor name -> temperature (Celsius).
    func readTemperatureSensors() -> [String: Double]?
}

protocol FanProviding {
    /// Returns fan speeds in RPM.
    func fanRPMs() -> [Double]?
}

struct SimulatedTemperatureProvider: TemperatureProviding {
    func cpuTemperatureC(currentCPUUsage: Double) -> Double? {
        SystemMetricsReader.simulateTemperature(cpuUsage: currentCPUUsage)
    }
}

/// Attempts to read real CPU temperature via IOKit/SMC. Returns nil if unavailable.
/// This is intentionally conservative and returns nil on any error so callers can fall back.
struct SMCTemperatureProvider: TemperatureProviding {
    func cpuTemperatureC(currentCPUUsage: Double) -> Double? {
        // Placeholder: Implement SMC access safely in a follow-up. For now, return nil.
        return nil
    }
}

/// Tries the real provider first, then falls back to simulation to ensure UI responsiveness.
struct CompositeTemperatureProvider: TemperatureProviding {
    let primary: TemperatureProviding
    let fallback: TemperatureProviding
    init(
        primary: TemperatureProviding = SMCTemperatureProvider(),
        fallback: TemperatureProviding = SimulatedTemperatureProvider()
    ) {
        self.primary = primary
        self.fallback = fallback
    }
    func cpuTemperatureC(currentCPUUsage: Double) -> Double? {
        primary.cpuTemperatureC(currentCPUUsage: currentCPUUsage)
            ?? fallback.cpuTemperatureC(currentCPUUsage: currentCPUUsage)
    }
}
