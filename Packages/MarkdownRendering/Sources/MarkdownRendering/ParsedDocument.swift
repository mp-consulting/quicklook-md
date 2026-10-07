import Foundation
import cmark_gfm
import cmark_gfm_extensions

typealias Node = UnsafeMutablePointer<cmark_node>

/// A cmark-gfm syntax tree for one Markdown source. Owns and frees the underlying C nodes.
final class ParsedDocument {
    let root: Node
    /// Block quotes recognized as GitHub alerts, with their markers already removed from the tree.
    private(set) var alerts: [Node: Alert] = [:]

    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist"]

    private static let registerExtensions: Void = {
        cmark_gfm_core_extensions_ensure_registered()
    }()

    init(markdown: String) {
        _ = Self.registerExtensions
        let parser = cmark_parser_new(CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES)!
        defer { cmark_parser_free(parser) }
        for name in Self.extensionNames {
            if let syntaxExtension = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, syntaxExtension)
            }
        }
        var markdown = markdown
        var mayContainAlerts = false
        markdown.withUTF8 { buffer in
            buffer.withMemoryRebound(to: CChar.self) { cmark_parser_feed(parser, $0.baseAddress, $0.count) }
            mayContainAlerts = memmem(buffer.baseAddress, buffer.count, "[!", 2) != nil
        }
        root = cmark_parser_finish(parser)
        // Merge adjacent text nodes: fewer nodes to render, and "[!NOTE]" becomes a single node.
        cmark_consolidate_text_nodes(root)
        // Most documents have no alerts; skip the extra tree walk for them.
        if mayContainAlerts { extractAlerts() }
    }

    deinit {
        cmark_node_free(root)
    }

    /// Finds `> [!KIND]` block quotes, records them, and strips the marker so it isn't rendered.
    private func extractAlerts() {
        var found: [(quote: Node, alert: Alert, marker: Node)] = []
        let iterator = cmark_iter_new(root)
        defer { cmark_iter_free(iterator) }
        while true {
            let event = cmark_iter_next(iterator)
            if event == CMARK_EVENT_DONE { break }
            guard event == CMARK_EVENT_ENTER, let node = cmark_iter_get_node(iterator),
                  cmark_node_get_type(node) == CMARK_NODE_BLOCK_QUOTE,
                  let paragraph = cmark_node_first_child(node), cmark_node_get_type(paragraph) == CMARK_NODE_PARAGRAPH,
                  let marker = cmark_node_first_child(paragraph), cmark_node_get_type(marker) == CMARK_NODE_TEXT,
                  let alert = Alert(marker: cmark_node_get_literal(marker)) else { continue }
            // The marker must sit alone on its line.
            if let next = cmark_node_next(marker), !Self.isLineBreak(next) { continue }
            found.append((node, alert, marker))
        }

        // Mutate only after iterating, which cmark requires.
        for (quote, alert, marker) in found {
            let paragraph = cmark_node_parent(marker)!
            if let lineBreak = cmark_node_next(marker) {
                cmark_node_free(lineBreak)
            }
            cmark_node_free(marker)
            if cmark_node_first_child(paragraph) == nil {
                cmark_node_free(paragraph)
            }
            alerts[quote] = alert
        }
    }

    private static func isLineBreak(_ node: Node) -> Bool {
        let type = cmark_node_get_type(node)
        return type == CMARK_NODE_SOFTBREAK || type == CMARK_NODE_LINEBREAK
    }
}

/// GitHub-style alerts: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`.
enum Alert: String, CaseIterable {
    case note, tip, important, warning, caution

    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    init?(marker literal: UnsafePointer<CChar>?) {
        guard let literal else { return nil }
        let marker = String(cString: literal).trimmingCharacters(in: .whitespaces).lowercased()
        guard marker.hasPrefix("[!"), marker.hasSuffix("]"),
              let alert = Alert(rawValue: String(marker.dropFirst(2).dropLast())) else { return nil }
        self = alert
    }
}
