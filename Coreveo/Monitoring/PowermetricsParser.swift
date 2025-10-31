import Foundation

/// Lightweight parser for `powermetrics` textual output.
/// Note: This is a best-effort, regex-driven parser aimed at stable fields only.
struct PowermetricsParser {
	struct Reading: Equatable {
		let metrics: [String: Double] // e.g., "CPU Die" → 65.2, "Processor Power" → 7.5
	}

	static func parse(_ text: String) -> Reading {
		var out: [String: Double] = [:]
		// Common temperature lines
		// Examples:
		// "CPU die temperature: 65.3 C"
		// "GPU die temperature: 52.1 C"
		let tempPatterns: [(name: String, regex: NSRegularExpression)]
		do {
			tempPatterns = [
				("CPU Die", try NSRegularExpression(pattern: #"CPU\s+die\s+temperature:\s*([0-9]+(?:\.[0-9]+)?)\s*C"#, options: .caseInsensitive)),
				("GPU Die", try NSRegularExpression(pattern: #"GPU\s+die\s+temperature:\s*([0-9]+(?:\.[0-9]+)?)\s*C"#, options: .caseInsensitive))
			]
		} catch {
			return Reading(metrics: [:])
		}
		for (name, regex) in tempPatterns {
			if let value = firstDouble(regex, in: text) { out[name] = value }
		}

		// Power lines
		// Examples:
		// "Processor Power: 7.50 W"
		// "GPU Power: 3.21 W"
		let powerPatterns: [(name: String, regex: NSRegularExpression)]
		do {
			powerPatterns = [
				("Processor Power", try NSRegularExpression(pattern: #"Processor\s+Power:\s*([0-9]+(?:\.[0-9]+)?)\s*W"#, options: .caseInsensitive)),
				("GPU Power", try NSRegularExpression(pattern: #"GPU\s+Power:\s*([0-9]+(?:\.[0-9]+)?)\s*W"#, options: .caseInsensitive))
			]
		} catch {
			return Reading(metrics: out)
		}
		for (name, regex) in powerPatterns {
			if let value = firstDouble(regex, in: text) { out[name] = value }
		}

		return Reading(metrics: out)
	}

	private static func firstDouble(_ regex: NSRegularExpression, in text: String) -> Double? {
		let range = NSRange(location: 0, length: text.utf16.count)
		guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges >= 2,
				let matchedRange = Range(match.range(at: 1), in: text) else { return nil }
		return Double(text[matchedRange])
	}
}
