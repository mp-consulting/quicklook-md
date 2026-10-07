@testable import MarkdownRendering

/// Renders a Markdown fragment with images passed through unchanged.
func render(_ markdown: String) -> String {
    MarkdownRendering.htmlFragment(from: markdown)
}
