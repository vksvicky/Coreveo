import Foundation

protocol TemperatureProviding {
    /// Returns CPU temperature in Celsius for a given current CPU usage hint.
    func cpuTemperatureC(currentCPUUsage: Double) -> Double?
}

struct SimulatedTemperatureProvider: TemperatureProviding {
    func cpuTemperatureC(currentCPUUsage: Double) -> Double? {
        SystemMetricsReader.simulateTemperature(cpuUsage: currentCPUUsage)
    }
}


