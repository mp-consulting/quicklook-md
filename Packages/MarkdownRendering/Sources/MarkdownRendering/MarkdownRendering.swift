import Foundation

public enum MarkdownRendering {
    /// Renders Markdown into a complete, self-contained HTML document with the bundled stylesheet.
    ///
    /// - Parameters:
    ///   - source: The Markdown text.
    ///   - title: Used for the document `<title>`.
    ///   - imageSource: Maps each image source (Markdown images and raw HTML `<img>` tags) to the URL
    ///     emitted in `src`. Called once per image, in document order.
    public static func htmlDocument(
        from source: String,
        title: String = "",
        imageSource: @escaping (String) -> String = { $0 }
    ) -> String {
        var html = HTMLBuffer(capacity: stylesheet.utf8.count + source.utf8.count * 2)
        html.append("""
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="color-scheme" content="light dark">
            <title>
            """)
        html.appendEscaped(title)
        html.append("</title>\n<style>\n")
        html.append(stylesheet)
        html.append("</style>\n</head>\n<body>\n<article class=\"markdown-body\">\n")
        appendBody(of: source, to: &html, imageSource: imageSource)
        html.append("</article>\n</body>\n</html>\n")
        return html.string
    }

    /// Renders Markdown into an HTML fragment, without the `<html>`/`<head>` wrapper or stylesheet.
    public static func htmlFragment(from source: String, imageSource: @escaping (String) -> String = { $0 }) -> String {
        var html = HTMLBuffer(capacity: source.utf8.count * 2)
        appendBody(of: source, to: &html, imageSource: imageSource)
        return html.string
    }

    private static func appendBody(of source: String, to html: inout HTMLBuffer, imageSource: @escaping (String) -> String) {
        let (frontMatter, body) = FrontMatter.split(source)
        if let frontMatter {
            html.append("<pre class=\"front-matter\"><code>")
            html.appendEscaped(frontMatter)
            html.append("</code></pre>\n")
        }
        let document = ParsedDocument(markdown: String(body))
        HTMLRenderer.render(document, into: &html, imageSource: imageSource)
    }

    static let stylesheet: String = {
        guard let url = Bundle.module.url(forResource: "style", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return css
    }()
}
