import Foundation

enum MDNode: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedList(items: [String])
    case orderedList(items: [String])
    case codeBlock(language: String?, code: String)
}

struct MDParser {
    func parse(_ markdown: String) -> [MDNode] {
        var nodes: [MDNode] = []
        var listBuffer: [String] = []
        var orderedListBuffer: [String] = []
        var codeBuffer: [String] = []
        var codeLang: String? = nil
        var inCode = false

        func flushParagraphIfNeeded(_ paragraphLines: inout [String]) {
            if !paragraphLines.isEmpty {
                let text = paragraphLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { nodes.append(.paragraph(text: text)) }
                paragraphLines.removeAll()
            }
        }

        func flushLists() {
            if !listBuffer.isEmpty { nodes.append(.unorderedList(items: listBuffer)); listBuffer.removeAll() }
            if !orderedListBuffer.isEmpty { nodes.append(.orderedList(items: orderedListBuffer)); orderedListBuffer.removeAll() }
        }

        var paragraphLines: [String] = []

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if line.hasPrefix("```") {
                if inCode {
                    nodes.append(.codeBlock(language: codeLang, code: codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll(); codeLang = nil; inCode = false
                } else {
                    flushParagraphIfNeeded(&paragraphLines)
                    flushLists()
                    inCode = true
                    let parts = line.dropFirst(3)
                    codeLang = parts.isEmpty ? nil : String(parts)
                }
                continue
            }

            if inCode {
                codeBuffer.append(line)
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraphIfNeeded(&paragraphLines)
                flushLists()
                continue
            }

            if let heading = parseHeading(line) {
                flushParagraphIfNeeded(&paragraphLines)
                flushLists()
                nodes.append(heading)
                continue
            }

            if let bullet = parseUnordered(line) {
                flushParagraphIfNeeded(&paragraphLines)
                // If we were building an ordered list and now see an unordered item,
                // flush the ordered list first so we don't lose it.
                if !orderedListBuffer.isEmpty {
                    nodes.append(.orderedList(items: orderedListBuffer))
                    orderedListBuffer.removeAll()
                }
                listBuffer.append(bullet)
                continue
            }

            if let ordered = parseOrdered(line) {
                flushParagraphIfNeeded(&paragraphLines)
                // If we were building an unordered list and now see an ordered item,
                // flush the unordered list first so we don't lose it.
                if !listBuffer.isEmpty {
                    nodes.append(.unorderedList(items: listBuffer))
                    listBuffer.removeAll()
                }
                orderedListBuffer.append(ordered)
                continue
            }

            paragraphLines.append(line)
        }

        if inCode { nodes.append(.codeBlock(language: codeLang, code: codeBuffer.joined(separator: "\n"))) }
        if !listBuffer.isEmpty { nodes.append(.unorderedList(items: listBuffer)) }
        if !orderedListBuffer.isEmpty { nodes.append(.orderedList(items: orderedListBuffer)) }
        if !paragraphLines.isEmpty { nodes.append(.paragraph(text: paragraphLines.joined(separator: " "))) }
        return nodes
    }

    private func parseHeading(_ line: String) -> MDNode? {
        var level = 0
        for ch in line { if ch == "#" { level += 1 } else { break } }
        guard level > 0, level <= 6 else { return nil }
        let text = line.drop(while: { $0 == "#" || $0 == " " })
        return .heading(level: level, text: text.isEmpty ? "" : String(text))
    }

    private func parseUnordered(_ line: String) -> String? {
        // Preserve leading indentation (spaces/tabs) for nested bullets
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        let rest = line.dropFirst(leading.count)
        if rest.hasPrefix("- ") || rest.hasPrefix("* ") {
            let content = rest.dropFirst(2)
            return String(leading) + String(content)
        }
        return nil
    }

    private func parseOrdered(_ line: String) -> String? {
        // Preserve leading indentation for nested ordered lists
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        let rest = line.dropFirst(leading.count)
        if let dotIndex = rest.firstIndex(of: ".") {
            let prefix = rest[..<dotIndex]
            if Int(prefix) != nil {
                let trailing = rest[rest.index(after: dotIndex)...]
                let trimmed = trailing.trimmingCharacters(in: .whitespaces)
                return String(leading) + trimmed
            }
        }
        return nil
    }
}


