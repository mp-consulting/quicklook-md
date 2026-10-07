/// Generates GitHub-style heading IDs: lowercased, punctuation dropped, spaces turned into dashes,
/// and a numeric suffix for repeats ("intro", "intro-1", …).
struct Slugger {
    private var used: [String: Int] = [:]

    mutating func uniqueSlug(for text: String) -> String {
        let base = Self.slug(text)
        let count = used[base, default: 0]
        used[base] = count + 1
        return count == 0 ? base : "\(base)-\(count)"
    }

    static func slug(_ text: String) -> String {
        var slug = String.UnicodeScalarView()
        for scalar in text.lowercased().unicodeScalars {
            if scalar == " " {
                slug.append("-")
            } else if scalar == "-" || scalar == "_" || isWordCharacter(scalar) {
                slug.append(scalar)
            }
        }
        return String(slug)
    }

    /// Letters, marks and numbers, with an ASCII fast path.
    static func isWordCharacter(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII {
            let value = scalar.value
            return (0x61...0x7A).contains(value) || (0x41...0x5A).contains(value) || (0x30...0x39).contains(value)
        }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark,
             .decimalNumber, .letterNumber, .otherNumber:
            return true
        default:
            return false
        }
    }
}
