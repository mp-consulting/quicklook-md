import Foundation
import Markdown

public enum MarkdownRendering {
    /// Renders Markdown source into a complete, self-contained HTML document.
    ///
    /// - Parameters:
    ///   - source: The Markdown text.
    ///   - title: Used for the document `<title>`.
    ///   - imageSource: Maps each image source found in the document to the URL emitted in `src`.
    public static func htmlDocument(
        from source: String,
        title: String = "",
        imageSource: @escaping (String) -> String = { $0 }
    ) -> String {
        let (frontMatter, body) = splitFrontMatter(source)
        var html = ""
        if let frontMatter {
            html += "<pre class=\"front-matter\"><code>\(frontMatter.htmlEscaped)</code></pre>\n"
        }
        html += htmlFragment(from: body, imageSource: imageSource)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <title>\(title.htmlEscaped)</title>
        <style>
        \(stylesheet)
        </style>
        </head>
        <body>
        <article class="markdown-body">
        \(html)</article>
        </body>
        </html>
        """
    }

    /// Renders Markdown source into an HTML fragment (no `<html>`/`<head>` wrapper).
    public static func htmlFragment(from source: String, imageSource: @escaping (String) -> String = { $0 }) -> String {
        let document = Document(parsing: source)
        var renderer = HTMLRenderer(imageSource: imageSource)
        return renderer.visit(document)
    }

    /// Collects every image source referenced by the Markdown, in document order.
    public static func imageSources(in source: String) -> [String] {
        var walker = ImageCollector()
        walker.visit(Document(parsing: splitFrontMatter(source).body))
        return walker.sources
    }

    /// Splits a leading YAML (`---`) or TOML (`+++`) front matter block from the body.
    static func splitFrontMatter(_ source: String) -> (frontMatter: String?, body: String) {
        let text = source.hasPrefix("\u{FEFF}") ? String(source.dropFirst()) : source
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first?.trimmingCharacters(in: .whitespaces), first == "---" || first == "+++" else {
            return (nil, text)
        }
        let fence = first
        for index in lines.indices.dropFirst() {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if line == fence || (fence == "---" && line == "...") {
                let frontMatter = lines[1..<index].joined(separator: "\n")
                lines.removeSubrange(0...index)
                return (frontMatter, lines.joined(separator: "\n"))
            }
        }
        return (nil, text)
    }

    static let stylesheet: String = {
        guard let url = Bundle.module.url(forResource: "style", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return css
    }()
}

private struct ImageCollector: MarkupWalker {
    var sources: [String] = []

    mutating func visitImage(_ image: Image) {
        if let source = image.source, !source.isEmpty { sources.append(source) }
        descendInto(image)
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        sources += htmlImageSources(html.rawHTML)
    }

    mutating func visitInlineHTML(_ html: InlineHTML) {
        sources += htmlImageSources(html.rawHTML)
    }

    private func htmlImageSources(_ html: String) -> [String] {
        let range = NSRange(html.startIndex..., in: html)
        return htmlImageSourceRegex.matches(in: html, range: range).compactMap { match in
            Range(match.range(at: 1), in: html).map { String(html[$0]) }
        }
    }
}

private let htmlImageSourceRegex = try! NSRegularExpression(
    pattern: #"<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']"#,
    options: .caseInsensitive
)

/// Rewrites the `src` of every `<img>` tag found in raw HTML.
func rewritingImageSources(in html: String, using imageSource: (String) -> String) -> String {
    let matches = htmlImageSourceRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
    var result = html
    for match in matches.reversed() {
        guard let range = Range(match.range(at: 1), in: result) else { continue }
        result.replaceSubrange(range, with: imageSource(String(result[range])))
    }
    return result
}
