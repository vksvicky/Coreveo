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
		let tempPatterns: [(name: String, regex: NSRegularExpression)] = [
			("CPU Die", try! NSRegularExpression(pattern: #"CPU\s+die\s+temperature:\s*([0-9]+(?:\.[0-9]+)?)\s*C"#, options: .caseInsensitive)),
			("GPU Die", try! NSRegularExpression(pattern: #"GPU\s+die\s+temperature:\s*([0-9]+(?:\.[0-9]+)?)\s*C"#, options: .caseInsensitive)),
		]
		for (name, re) in tempPatterns {
			if let v = firstDouble(re, in: text) { out[name] = v }
		}

		// Power lines
		// Examples:
		// "Processor Power: 7.50 W"
		// "GPU Power: 3.21 W"
		let powerPatterns: [(name: String, regex: NSRegularExpression)] = [
			("Processor Power", try! NSRegularExpression(pattern: #"Processor\s+Power:\s*([0-9]+(?:\.[0-9]+)?)\s*W"#, options: .caseInsensitive)),
			("GPU Power", try! NSRegularExpression(pattern: #"GPU\s+Power:\s*([0-9]+(?:\.[0-9]+)?)\s*W"#, options: .caseInsensitive)),
		]
		for (name, re) in powerPatterns { if let v = firstDouble(re, in: text) { out[name] = v } }

		return Reading(metrics: out)
	}

	private static func firstDouble(_ re: NSRegularExpression, in text: String) -> Double? {
		let range = NSRange(location: 0, length: text.utf16.count)
		guard let m = re.firstMatch(in: text, options: [], range: range), m.numberOfRanges >= 2,
				let r = Range(m.range(at: 1), in: text) else { return nil }
		return Double(text[r])
	}
}


