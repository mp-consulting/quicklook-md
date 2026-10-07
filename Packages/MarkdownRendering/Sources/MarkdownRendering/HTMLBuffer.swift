import Foundation

/// Accumulates HTML as UTF-8 bytes, escaping text directly from cmark's C strings.
struct HTMLBuffer {
    private(set) var bytes: [UInt8] = []

    init(capacity: Int = 0) {
        bytes.reserveCapacity(capacity)
    }

    var string: String { String(decoding: bytes, as: UTF8.self) }

    mutating func append(_ literal: StaticString) {
        literal.withUTF8Buffer { bytes.append(contentsOf: $0) }
    }

    mutating func append(_ string: String) {
        bytes.append(contentsOf: string.utf8)
    }

    mutating func append(_ value: Int) {
        append(String(value))
    }

    mutating func append(_ raw: UnsafeRawBufferPointer) {
        bytes.append(contentsOf: raw)
    }

    /// Appends a NUL-terminated C string without escaping.
    mutating func appendRaw(_ cString: UnsafePointer<CChar>?) {
        guard let cString else { return }
        append(UnsafeRawBufferPointer(start: cString, count: strlen(cString)))
    }

    /// Appends a NUL-terminated C string, escaping `&`, `<`, `>` and `"`.
    mutating func appendEscaped(_ cString: UnsafePointer<CChar>?) {
        guard let cString else { return }
        appendEscaped(UnsafeRawBufferPointer(start: cString, count: strlen(cString)))
    }

    mutating func appendEscaped(_ string: String) {
        var string = string
        string.withUTF8 { appendEscaped(UnsafeRawBufferPointer($0)) }
    }

    /// Copies runs of safe bytes in bulk and only branches on the four characters that need escaping.
    mutating func appendEscaped(_ source: UnsafeRawBufferPointer) {
        var runStart = 0
        for (index, byte) in source.enumerated() {
            let replacement: StaticString
            switch byte {
            case UInt8(ascii: "&"): replacement = "&amp;"
            case UInt8(ascii: "<"): replacement = "&lt;"
            case UInt8(ascii: ">"): replacement = "&gt;"
            case UInt8(ascii: "\""): replacement = "&quot;"
            default: continue
            }
            if index > runStart {
                append(UnsafeRawBufferPointer(rebasing: source[runStart..<index]))
            }
            append(replacement)
            runStart = index + 1
        }
        if runStart < source.count {
            append(UnsafeRawBufferPointer(rebasing: source[runStart...]))
        }
    }
}

extension String {
    var htmlEscaped: String {
        var buffer = HTMLBuffer(capacity: utf8.count)
        buffer.appendEscaped(self)
        return buffer.string
    }
}
