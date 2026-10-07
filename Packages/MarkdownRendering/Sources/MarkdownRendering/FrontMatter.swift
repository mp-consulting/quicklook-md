import Foundation

/// A leading YAML (`---`) or TOML (`+++`) metadata block.
enum FrontMatter {
    /// Splits front matter from the Markdown body. Returns `nil` front matter when there is none
    /// or its closing fence is missing.
    static func split(_ source: String) -> (frontMatter: String?, body: Substring) {
        var text = source[...]
        if text.hasPrefix("\u{FEFF}") { text = text.dropFirst() }
        // Cheap exit for the common case, before any line scanning.
        guard text.hasPrefix("---") || text.hasPrefix("+++") else { return (nil, text) }
        let fence = String(text.prefix(3))

        var lineStart = text.startIndex
        var contentStart: Substring.Index?
        while true {
            // `isNewline` treats "\r\n" as a single character, so CRLF files work too.
            let lineEnd = text[lineStart...].firstIndex(where: \.isNewline) ?? text.endIndex
            let line = text[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces)
            let nextLine = lineEnd == text.endIndex ? lineEnd : text.index(after: lineEnd)

            if let start = contentStart {
                if line == fence || (fence == "---" && line == "...") {
                    var frontMatter = text[start..<lineStart]
                    if frontMatter.last?.isNewline == true { frontMatter = frontMatter.dropLast() }
                    return (String(frontMatter), text[nextLine...])
                }
            } else {
                guard line == fence else { return (nil, text) }
                contentStart = nextLine
            }
            if lineEnd == text.endIndex { return (nil, text) }
            lineStart = nextLine
        }
    }
}
