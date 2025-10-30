import SwiftUI

struct MDView: View {
    let markdown: String
    private let parser = MDParser()

    var body: some View {
        let nodes = parser.parse(markdown)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    render(node)
                }
            }
            .padding(16)
        }
        // color scheme applied by parent view
    }

    @ViewBuilder
    private func render(_ node: MDNode) -> some View {
        switch node {
        case let .heading(level, text):
            Text(text)
                .font(fontForHeading(level))
                .fontWeight(.bold)
                .padding(.top, level == 1 ? 8 : 4)
        case let .paragraph(text):
            renderInlineMathLine(text)
        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let indent = leadingIndent(in: item)
                    let content = stripLeadingIndent(item)
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").font(.body)
                        renderInlineMathLine(content)
                    }
                    .padding(.leading, CGFloat(indent) * 8)
                }
            }
        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    let indent = leadingIndent(in: item)
                    let content = stripLeadingIndent(item)
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).").font(.body)
                        renderInlineMathLine(content)
                    }
                    .padding(.leading, CGFloat(indent) * 8)
                }
            }
        case let .codeBlock(_, code):
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
            }
        }
    }

    private func fontForHeading(_ level: Int) -> Font {
        switch level {
            case 1: return .system(size: 28, weight: .bold)
            case 2: return .system(size: 22, weight: .bold)
            case 3: return .system(size: 18, weight: .semibold)
            default: return .headline
        }
    }

    private func isFormula(_ text: String) -> Bool {
        // Heuristic: treat as formula if it contains '=' and any math-like token
        if text.contains("=") {
            let tokens = ["Δ", "/", "(", ")", "max(", "min(", "argmax", ":"]
            return tokens.first(where: { text.contains($0) }) != nil
        }
        return false
    }

    // MARK: - Structured formula rendering (heuristics for our help text)

    @ViewBuilder
    private func renderIdentifier(_ base: String, subscript sub: String?) -> some View {
        if let sub = sub, !sub.isEmpty {
            HStack(spacing: 0) {
                Text(base)
                Text(sub)
                    .font(.footnote)
                    .baselineOffset(-4)
            }
        } else {
            Text(base)
        }
    }

    private struct FractionView: View {
        let numerator: String
        let denominator: String
        var body: some View {
            let width = estimatedWidth()
            return VStack(spacing: 2) {
                Text(numerator)
                    .font(.body)
                Rectangle()
                    .frame(width: width, height: 1)
                    .foregroundColor(Color.secondary)
                Text(denominator)
                    .font(.body)
            }
            .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
            .fixedSize()
        }

        private func estimatedWidth() -> CGFloat {
            let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let num = (numerator as NSString).size(withAttributes: [.font: font]).width
            let den = (denominator as NSString).size(withAttributes: [.font: font]).width
            return max(num, den) + 4
        }
    }

    // Attempts to turn specific lines into structured math views
    private func renderStructuredFormula(_ raw: String) -> AnyView? {
        // Normalize en dash to minus
        var text = raw.replacingOccurrences(of: "–", with: "-")
        text = text.replacingOccurrences(of: "−", with: "-")

        // usage = (Δuser + Δsystem + Δnice) / Δtotal
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("usage = ") && text.contains("/") {
            let lhs = Text("usage = ")
            let fractionParts = extractFraction(from: text)
            let view = HStack(alignment: .center, spacing: 8) {
                lhs
                if let (num, den) = fractionParts {
                    FractionView(numerator: num, denominator: den)
                } else {
                    Text(text)
                }
            }
            return AnyView(view)
        }

        // Equivalent: usage = 1 - (Δidle / Δtotal)
        if text.lowercased().contains("equivalent") && text.contains("/") {
            let prefixRange = text.range(of: ":")
            let prefix = prefixRange != nil ? String(text[..<prefixRange!.upperBound]) + " " : ""
            let suffix = prefixRange != nil ? String(text[prefixRange!.upperBound...]).trimmingCharacters(in: .whitespaces) : text
            let pieces = suffix.split(separator: "-")
            if pieces.count == 2 {
                let left = pieces[0].trimmingCharacters(in: .whitespaces) // "usage = 1"
                let right = String(pieces[1]).trimmingCharacters(in: .whitespaces)
            let view = HStack(alignment: .center, spacing: 4) {
                Text(prefix + left + " − (")
                    if let (num, den) = extractFraction(from: right) {
                        FractionView(numerator: num, denominator: den)
                    } else {
                        Text(right)
                    }
                Text(")")
                }
                return AnyView(view)
            }
        }

        return nil
    }

    private func extractFraction(from text: String) -> (String, String)? {
        // Expect something like "(A) / B" or "A / B"; strip surrounding parentheses
        guard let slash = text.firstIndex(of: "/") else { return nil }
        let left = String(text[..<slash]).trimmingCharacters(in: .whitespaces)
        let right = String(text[text.index(after: slash)...]).trimmingCharacters(in: .whitespaces)
        let num = stripOuterParens(left)
        let den = stripOuterParens(right)
        return (num, den)
    }

    private func stripOuterParens(_ s: String) -> String {
        var result = s
        if result.hasPrefix("(") && result.hasSuffix(")") {
            result.removeFirst()
            result.removeLast()
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Inline math rendering (generic)

    private func renderInlineMathLine(_ text: String) -> AnyView {
        // Preferred path: explicit math spans delimited by $...$
        if text.contains("$") {
            return renderDollarMathLine(text)
        }
        // Fallback heuristics for older help content
        if let view = renderStructuredFormula(text) { return view }
        let runs = inlineMathRuns(text)
        let combined = textFromRuns(runs)
            .font(isFormula(text) ? .system(.body, design: .monospaced) : .body)
        return AnyView(combined)
    }

    private enum InlineRun {
        case plain(String)
        case delta(String, String) // e.g., Δ + user
        case subscripted(String, String) // e.g., usage_i, i_peak, arg max_i
    }

    private func inlineMathRuns(_ text: String) -> [InlineRun] {
        tokenizeMath(text)
    }

    @ViewBuilder
    private func renderInlineMathRuns(_ text: String) -> some View {
        let runs = tokenizeMath(text)
        ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
            switch run {
            case let .plain(s): Text(s)
            case let .delta(base, sub): renderIdentifier(base, subscript: sub)
            case let .subscripted(base, sub):
                HStack(spacing: 0) {
                    Text(base)
                    Text(sub).font(.footnote).baselineOffset(-4)
                }
            }
        }
    }

    private func tokenizeMath(_ text: String) -> [InlineRun] {
        // Support three token types: Δword, word_sub, and "arg max_sub"
        let ns = text as NSString
        var runs: [InlineRun] = []
        var cursor = 0
        // Combine patterns into a single regex using alternation
        let combined = "(Δ([A-Za-z]+))|(([A-Za-z]+)_([A-Za-z]+))|(arg max_([A-Za-z]+))"
        guard let regex = try? NSRegularExpression(pattern: combined, options: []) else {
            return [.plain(text)]
        }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return [.plain(text)] }
        for m in matches {
            let r = m.range
            if r.location > cursor {
                runs.append(.plain(ns.substring(with: NSRange(location: cursor, length: r.location - cursor))))
            }
            // Determine which alternative matched
            if m.range(at: 1).location != NSNotFound {
                // Δword -> delta
                let sub = ns.substring(with: m.range(at: 2))
                runs.append(.delta("Δ", sub))
            } else if m.range(at: 4).location != NSNotFound {
                // word_sub -> subscripted
                let base = ns.substring(with: m.range(at: 4))
                let sub = ns.substring(with: m.range(at: 5))
                runs.append(.subscripted(base, sub))
            } else if m.range(at: 7).location != NSNotFound {
                // arg max_sub -> subscripted with base "arg max"
                let sub = ns.substring(with: m.range(at: 7))
                runs.append(.subscripted("arg max", sub))
            }
            cursor = r.location + r.length
        }
        if cursor < ns.length {
            runs.append(.plain(ns.substring(from: cursor)))
        }
        return runs
    }

    private func textFromRuns(_ runs: [InlineRun]) -> Text {
        var t = Text("")
        for run in runs {
            switch run {
            case let .plain(s):
                t = t + Text(s)
            case let .delta(base, sub):
                t = t + Text(base) + Text(sub).font(.footnote).baselineOffset(-4)
            case let .subscripted(base, sub):
                t = t + Text(base) + Text(sub).font(.footnote).baselineOffset(-4)
            }
        }
        return t
    }

    // MARK: - $...$ math spans

    private func renderDollarMathLine(_ text: String) -> AnyView {
        // Split by $; odd indices are math spans
        let parts = text.split(separator: "$", omittingEmptySubsequences: false)
        var segments: [AnyView] = []
        for (idx, part) in parts.enumerated() {
            let s = String(part)
            if idx % 2 == 1 { // math span
                if let (prefix, num, den, suffix) = firstInlineFraction(in: s) {
                    if !prefix.isEmpty {
                        segments.append(AnyView(textFromRuns(tokenizeMath(prefix))))
                    }
                    segments.append(AnyView(FractionView(numerator: num, denominator: den)))
                    if !suffix.isEmpty {
                        segments.append(AnyView(textFromRuns(tokenizeMath(suffix))))
                    }
                } else {
                    segments.append(AnyView(textFromRuns(tokenizeMath(s))))
                }
            } else {
                segments.append(AnyView(Text(s)))
            }
        }
        let view = HStack(alignment: .center, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                seg
            }
        }.font(.body)
        return AnyView(view)
    }

    private func firstInlineFraction(in text: String) -> (String, String, String, String)? {
        // Match prefix (optional), numerator, denominator, suffix
        // Look for something like "( … ) / …" or "… / …"; choose the first occurrence
        guard let slash = text.firstIndex(of: "/") else { return nil }
        // Find start of numerator: prefer nearest '(' before slash
        let before = text[..<slash]
        var numStart = before.startIndex
        if let open = before.lastIndex(of: "(") {
            numStart = text.index(after: open)
        }
        let numerator = String(text[numStart..<slash]).trimmingCharacters(in: .whitespaces)
        // Denominator to end or until closing ')'
        var denEnd = text.endIndex
        if let close = text.firstIndex(of: ")") , close > slash { denEnd = close }
        let denominator = String(text[text.index(after: slash)..<denEnd]).trimmingCharacters(in: .whitespaces)
        let prefix = String(text[..<numStart]).trimmingCharacters(in: .whitespaces)
        let suffix = String(text[denEnd...]).trimmingCharacters(in: .whitespaces)
        guard !numerator.isEmpty, !denominator.isEmpty else { return nil }
        return (prefix, numerator, denominator, suffix)
    }

    // Indentation helpers for list items that encoded leading spaces
    private func leadingIndent(in item: String) -> Int {
        var count = 0
        for ch in item {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 4 }
            else { break }
        }
        return count
    }

    private func stripLeadingIndent(_ item: String) -> String {
        var idx = item.startIndex
        for ch in item {
            if ch == " " || ch == "\t" { idx = item.index(after: idx) } else { break }
        }
        return String(item[idx...])
    }
}


