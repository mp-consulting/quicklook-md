/// Rewrites the `src` attribute of every `<img>` tag in a raw HTML snippet.
func rewritingImageSources(in html: String, using imageSource: (String) -> String) -> String {
    var out = HTMLBuffer(capacity: html.utf8.count)
    var html = html
    html.withUTF8 { appendRewritingImageSources(UnsafeRawBufferPointer($0), to: &out, using: imageSource) }
    return out.string
}

/// Copies raw HTML to `out`, passing each `<img>` tag's `src` value through `imageSource`.
///
/// A small byte scanner rather than a regular expression: raw HTML is common in READMEs and this runs on
/// every HTML node. Matches `src` only as a whole attribute name, so `data-src` is left alone.
func appendRewritingImageSources(
    _ html: UnsafeRawBufferPointer,
    to out: inout HTMLBuffer,
    using imageSource: (String) -> String
) {
    var copied = 0
    var index = 0
    while let tagStart = findImageTag(in: html, from: index) {
        let tagEnd = html[tagStart...].firstIndex(of: UInt8(ascii: ">")) ?? html.count
        if let value = findSourceValue(in: html, tagRange: tagStart + 4..<tagEnd) {
            out.append(UnsafeRawBufferPointer(rebasing: html[copied..<value.lowerBound]))
            let source = String(decoding: UnsafeRawBufferPointer(rebasing: html[value]), as: UTF8.self)
            out.append(imageSource(source))
            copied = value.upperBound
        }
        index = tagEnd
    }
    out.append(UnsafeRawBufferPointer(rebasing: html[copied...]))
}

/// Finds `<img` (any case) followed by whitespace, `/` or `>`.
private func findImageTag(in html: UnsafeRawBufferPointer, from start: Int) -> Int? {
    var index = start
    while index + 4 < html.count {
        if html[index] == UInt8(ascii: "<"),
           html[index + 1] | 0x20 == UInt8(ascii: "i"),
           html[index + 2] | 0x20 == UInt8(ascii: "m"),
           html[index + 3] | 0x20 == UInt8(ascii: "g"),
           isWhitespace(html[index + 4]) || html[index + 4] == UInt8(ascii: "/") || html[index + 4] == UInt8(ascii: ">") {
            return index
        }
        index += 1
    }
    return nil
}

/// Returns the byte range of the `src` attribute's value within a tag, quoted or not.
private func findSourceValue(in html: UnsafeRawBufferPointer, tagRange: Range<Int>) -> Range<Int>? {
    var index = tagRange.lowerBound
    while index + 3 <= tagRange.upperBound {
        defer { index += 1 }
        guard isWhitespace(html[index - 1]),
              html[index] | 0x20 == UInt8(ascii: "s"),
              html[index + 1] | 0x20 == UInt8(ascii: "r"),
              html[index + 2] | 0x20 == UInt8(ascii: "c") else { continue }
        var cursor = skipWhitespace(html, from: index + 3, upTo: tagRange.upperBound)
        guard cursor < tagRange.upperBound, html[cursor] == UInt8(ascii: "=") else { continue }
        cursor = skipWhitespace(html, from: cursor + 1, upTo: tagRange.upperBound)
        guard cursor < tagRange.upperBound else { return nil }

        let quote = html[cursor]
        if quote == UInt8(ascii: "\"") || quote == UInt8(ascii: "'") {
            let valueStart = cursor + 1
            guard let valueEnd = html[valueStart..<tagRange.upperBound].firstIndex(of: quote) else { return nil }
            return valueStart..<valueEnd
        }
        var valueEnd = cursor
        while valueEnd < tagRange.upperBound, !isWhitespace(html[valueEnd]) { valueEnd += 1 }
        return cursor..<valueEnd
    }
    return nil
}

private func skipWhitespace(_ html: UnsafeRawBufferPointer, from start: Int, upTo end: Int) -> Int {
    var index = start
    while index < end, isWhitespace(html[index]) { index += 1 }
    return index
}

private func isWhitespace(_ byte: UInt8) -> Bool {
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D || byte == 0x0C
}
