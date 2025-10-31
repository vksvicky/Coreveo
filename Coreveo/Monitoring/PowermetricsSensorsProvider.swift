import Foundation

/// Reads temperature sensors by invoking powermetrics and parsing its output.
/// Best‑effort: returns nil if powermetrics is unavailable or access is denied.
struct PowermetricsSensorsProvider: TemperatureSensorsProviding {
	func readTemperatureSensors() -> [String : Double]? {
		guard let text = runPowermetricsOnce() else { return nil }
		let reading = PowermetricsParser.parse(text)
		return reading.metrics.isEmpty ? nil : reading.metrics
	}

	private func runPowermetricsOnce() -> String? {
		let task = Process()
		task.launchPath = "/usr/bin/powermetrics"
		task.arguments = ["-n", "1", "--samplers", "thermal"]
		let pipe = Pipe()
		task.standardOutput = pipe
		task.standardError = Pipe()
		do {
			try task.run()
		} catch {
			return nil
		}
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return nil }
		return str
	}
}

/// Merges multiple temperature sensor providers, later providers override same keys.
struct MergedTemperatureSensorsProvider: TemperatureSensorsProviding {
	let providers: [TemperatureSensorsProviding]
	init(_ providers: [TemperatureSensorsProviding]) { self.providers = providers }
	func readTemperatureSensors() -> [String : Double]? {
		var result: [String: Double] = [:]
		for p in providers {
			if let map = p.readTemperatureSensors() {
				for (k, v) in map { result[k] = v }
			}
		}
		return result.isEmpty ? nil : result
	}
}


