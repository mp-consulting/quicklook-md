import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Renders a cmark-gfm syntax tree to GitHub-flavored HTML in a single pass.
struct HTMLRenderer {
    private var out: HTMLBuffer
    private let document: ParsedDocument
    private let imageSource: (String) -> String

    private var slugger = Slugger()
    private var extensionKinds: [UInt32: ExtensionKind] = [:]

    // Table state. Tables can't nest, so one set suffices.
    private var tableAlignments: UnsafeMutablePointer<UInt8>?
    private var tableColumns = 0
    private var cellIndex = 0
    private var inHeaderRow = false
    private var tableBodyOpen = false

    // Footnote state.
    private var footnotesOpen = false
    private var footnoteReferenceCounts: [String: Int] = [:]
    private var footnoteIDs: [Node: String] = [:]

    /// A loose task item whose checkbox goes inside its first paragraph.
    private var pendingCheckbox: Node?
    private var backReferenceWritten = false

    private enum ExtensionKind {
        case table, tableRow, tableCell, strikethrough, other
    }

    /// Renders `document` and appends the HTML to `buffer`.
    static func render(_ document: ParsedDocument, into buffer: inout HTMLBuffer, imageSource: @escaping (String) -> String) {
        var renderer = HTMLRenderer(out: buffer, document: document, imageSource: imageSource)
        buffer = HTMLBuffer() // Hand over storage so appends don't copy.
        renderer.renderTree()
        buffer = renderer.out
    }

    private init(out: HTMLBuffer, document: ParsedDocument, imageSource: @escaping (String) -> String) {
        self.out = out
        self.document = document
        self.imageSource = imageSource
    }

    private mutating func renderTree() {
        let iterator = cmark_iter_new(document.root)
        defer { cmark_iter_free(iterator) }

        while true {
            let event = cmark_iter_next(iterator)
            if event == CMARK_EVENT_DONE { break }
            guard let node = cmark_iter_get_node(iterator) else { continue }
            let entering = event == CMARK_EVENT_ENTER

            switch cmark_node_get_type(node) {
            case CMARK_NODE_DOCUMENT:
                if !entering, footnotesOpen { out.append("</ol>\n</section>\n") }
            case CMARK_NODE_PARAGRAPH:
                paragraph(node, entering: entering)
            case CMARK_NODE_TEXT:
                out.appendEscaped(cmark_node_get_literal(node))
            case CMARK_NODE_SOFTBREAK:
                out.append("\n")
            case CMARK_NODE_LINEBREAK:
                out.append("<br>\n")
            case CMARK_NODE_CODE:
                out.append("<code>")
                out.appendEscaped(cmark_node_get_literal(node))
                out.append("</code>")
            case CMARK_NODE_EMPH:
                out.append(entering ? "<em>" : "</em>")
            case CMARK_NODE_STRONG:
                out.append(entering ? "<strong>" : "</strong>")
            case CMARK_NODE_LINK:
                link(node, entering: entering)
            case CMARK_NODE_IMAGE:
                image(node)
                // The alt text has been written; skip the image's children.
                cmark_iter_reset(iterator, node, CMARK_EVENT_EXIT)
            case CMARK_NODE_HTML_BLOCK, CMARK_NODE_HTML_INLINE:
                rawHTML(cmark_node_get_literal(node))
            case CMARK_NODE_HEADING:
                heading(node, entering: entering)
            case CMARK_NODE_BLOCK_QUOTE:
                blockQuote(node, entering: entering)
            case CMARK_NODE_LIST:
                list(node, entering: entering)
            case CMARK_NODE_ITEM:
                item(node, entering: entering)
            case CMARK_NODE_CODE_BLOCK:
                codeBlock(node)
            case CMARK_NODE_THEMATIC_BREAK:
                out.append("<hr>\n")
            case CMARK_NODE_FOOTNOTE_REFERENCE:
                // Not a leaf for cmark's iterator, so it's visited on exit too.
                if entering { footnoteReference(node) }
            case CMARK_NODE_FOOTNOTE_DEFINITION:
                footnoteDefinition(node, entering: entering)
            default:
                extensionNode(node, entering: entering)
            }
        }
    }

    // MARK: Blocks

    private mutating func paragraph(_ node: Node, entering: Bool) {
        let parent = cmark_node_parent(node)
        // Paragraphs in tight list items render bare, as on GitHub.
        let tight = parent.map { cmark_node_get_type($0) == CMARK_NODE_ITEM && Self.isInTightList($0) } ?? false
        if entering {
            if !tight { out.append("<p>") }
            if let item = pendingCheckbox, item == parent {
                appendCheckbox(for: item)
                pendingCheckbox = nil
            }
            return
        }
        if let parent, cmark_node_get_type(parent) == CMARK_NODE_FOOTNOTE_DEFINITION, cmark_node_next(node) == nil {
            footnoteBackReference(parent)
        }
        if !tight { out.append("</p>\n") }
    }

    private mutating func heading(_ node: Node, entering: Bool) {
        let level = Int(cmark_node_get_heading_level(node))
        guard entering else {
            out.append("</h")
            out.append(level)
            out.append(">\n")
            return
        }
        let id = slugger.uniqueSlug(for: Self.plainText(of: node)).htmlEscaped
        out.append("<h")
        out.append(level)
        out.append(" id=\"")
        out.append(id)
        out.append("\"><a class=\"anchor\" href=\"#")
        out.append(id)
        out.append("\"></a>")
    }

    private mutating func blockQuote(_ node: Node, entering: Bool) {
        if let alert = document.alerts[node] {
            if entering {
                out.append("<div class=\"alert alert-")
                out.append(alert.rawValue)
                out.append("\"><p class=\"alert-title\">")
                out.append(alert.title)
                out.append("</p>\n")
            } else {
                out.append("</div>\n")
            }
        } else {
            out.append(entering ? "<blockquote>\n" : "</blockquote>\n")
        }
    }

    private mutating func list(_ node: Node, entering: Bool) {
        let ordered = cmark_node_get_list_type(node) == CMARK_ORDERED_LIST
        guard entering else {
            out.append(ordered ? "</ol>\n" : "</ul>\n")
            return
        }
        if let parent = cmark_node_parent(node), cmark_node_get_type(parent) == CMARK_NODE_ITEM, cmark_node_previous(node) != nil,
           Self.isInTightList(parent) {
            out.append("\n")
        }
        out.append(ordered ? "<ol" : "<ul")
        let start = Int(cmark_node_get_list_start(node))
        if ordered, start != 1 {
            out.append(" start=\"")
            out.append(start)
            out.append("\"")
        }
        if Self.containsTaskItem(node) {
            out.append(" class=\"contains-task-list\"")
        }
        out.append(">\n")
    }

    private mutating func item(_ node: Node, entering: Bool) {
        guard entering else {
            out.append("</li>\n")
            return
        }
        guard Self.isTaskItem(node) else {
            out.append("<li>")
            return
        }
        out.append("<li class=\"task-list-item\">")
        // GitHub puts the checkbox inside the first paragraph of a loose item.
        if let first = cmark_node_first_child(node), cmark_node_get_type(first) == CMARK_NODE_PARAGRAPH, !Self.isInTightList(node) {
            pendingCheckbox = node
        } else {
            appendCheckbox(for: node)
        }
    }

    private mutating func appendCheckbox(for item: Node) {
        out.append(cmark_gfm_extensions_get_tasklist_item_checked(item)
            ? "<input type=\"checkbox\" disabled checked> "
            : "<input type=\"checkbox\" disabled> ")
    }

    private mutating func codeBlock(_ node: Node) {
        let language = Self.language(fromInfo: cmark_node_get_fence_info(node))
        if let language {
            out.append("<pre data-lang=\"")
            out.appendEscaped(language)
            out.append("\"><code class=\"language-")
            out.appendEscaped(language)
            out.append("\">")
        } else {
            out.append("<pre><code>")
        }
        out.appendEscaped(cmark_node_get_literal(node))
        out.append("</code></pre>\n")
    }

    private mutating func rawHTML(_ literal: UnsafePointer<CChar>?) {
        guard let literal else { return }
        let html = UnsafeRawBufferPointer(start: literal, count: strlen(literal))
        appendRewritingImageSources(html, to: &out, using: imageSource)
    }

    // MARK: Inlines

    private mutating func link(_ node: Node, entering: Bool) {
        guard entering else {
            out.append("</a>")
            return
        }
        out.append("<a href=\"")
        out.appendEscaped(cmark_node_get_url(node))
        out.append("\"")
        appendTitle(of: node)
        out.append(">")
    }

    private mutating func image(_ node: Node) {
        let url = cmark_node_get_url(node).map { String(cString: $0) } ?? ""
        out.append("<img src=\"")
        out.appendEscaped(imageSource(url))
        out.append("\" alt=\"")
        out.appendEscaped(Self.plainText(of: node))
        out.append("\"")
        appendTitle(of: node)
        out.append(">")
    }

    private mutating func appendTitle(of node: Node) {
        guard let title = cmark_node_get_title(node), title.pointee != 0 else { return }
        out.append(" title=\"")
        out.appendEscaped(title)
        out.append("\"")
    }

    // MARK: Footnotes

    private mutating func footnoteReference(_ node: Node) {
        guard let definition = cmark_node_parent_footnote_def(node) else { return }
        let id = footnoteID(definition)
        let count = footnoteReferenceCounts[id, default: 0] + 1
        footnoteReferenceCounts[id] = count
        out.append("<sup class=\"footnote-ref\"><a href=\"#fn-")
        out.append(id)
        out.append("\" id=\"fnref-")
        out.append(id)
        if count > 1 {
            out.append("-")
            out.append(count)
        }
        out.append("\">")
        out.appendEscaped(cmark_node_get_literal(node))
        out.append("</a></sup>")
    }

    private mutating func footnoteDefinition(_ node: Node, entering: Bool) {
        if entering {
            if !footnotesOpen {
                out.append("<section class=\"footnotes\">\n<ol>\n")
                footnotesOpen = true
            }
            backReferenceWritten = false
            out.append("<li id=\"fn-")
            out.append(footnoteID(node))
            out.append("\">\n")
        } else {
            if !backReferenceWritten { footnoteBackReference(node) }
            out.append("</li>\n")
        }
    }

    private mutating func footnoteBackReference(_ definition: Node) {
        out.append(" <a href=\"#fnref-")
        out.append(footnoteID(definition))
        out.append("\" class=\"footnote-backref\" aria-label=\"Back to reference\">↩</a>")
        backReferenceWritten = true
    }

    // MARK: Extensions

    private mutating func extensionNode(_ node: Node, entering: Bool) {
        switch extensionKind(of: node) {
        case .table:
            if entering {
                tableAlignments = cmark_gfm_extensions_get_table_alignments(node)
                tableColumns = Int(cmark_gfm_extensions_get_table_columns(node))
                tableBodyOpen = false
                out.append("<table>\n")
            } else {
                if tableBodyOpen { out.append("</tbody>\n") }
                out.append("</table>\n")
            }
        case .tableRow where cmark_gfm_extensions_get_table_row_is_header(node) != 0:
            inHeaderRow = entering
            cellIndex = 0
            out.append(entering ? "<thead>\n<tr>\n" : "</tr>\n</thead>\n")
        case .tableRow:
            if entering {
                if !tableBodyOpen {
                    out.append("<tbody>\n")
                    tableBodyOpen = true
                }
                cellIndex = 0
                out.append("<tr>\n")
            } else {
                out.append("</tr>\n")
            }
        case .tableCell:
            tableCell(entering: entering)
        case .strikethrough:
            out.append(entering ? "<del>" : "</del>")
        case .other:
            break
        }
    }

    private mutating func tableCell(entering: Bool) {
        guard entering else {
            out.append(inHeaderRow ? "</th>\n" : "</td>\n")
            cellIndex += 1
            return
        }
        out.append(inHeaderRow ? "<th" : "<td")
        if let tableAlignments, cellIndex < tableColumns {
            switch tableAlignments[cellIndex] {
            case UInt8(ascii: "l"): out.append(" align=\"left\"")
            case UInt8(ascii: "c"): out.append(" align=\"center\"")
            case UInt8(ascii: "r"): out.append(" align=\"right\"")
            default: break
            }
        }
        out.append(">")
    }

    /// Extension node types are assigned at runtime, so they're identified by name once per type and cached.
    /// Header and body rows share a type; `tableRow` covers both.
    private mutating func extensionKind(of node: Node) -> ExtensionKind {
        let type = cmark_node_get_type(node).rawValue
        if let kind = extensionKinds[type] { return kind }
        let kind: ExtensionKind
        switch String(cString: cmark_node_get_type_string(node)) {
        case "table": kind = .table
        case "table_header", "table_row": kind = .tableRow
        case "table_cell": kind = .tableCell
        case "strikethrough": kind = .strikethrough
        default: kind = .other
        }
        extensionKinds[type] = kind
        return kind
    }

    // MARK: Helpers

    /// The text content of a node's descendants, as used for heading IDs and image alt text.
    static func plainText(of node: Node) -> String {
        var text = HTMLBuffer()
        let iterator = cmark_iter_new(node)
        defer { cmark_iter_free(iterator) }
        while true {
            let event = cmark_iter_next(iterator)
            if event == CMARK_EVENT_DONE { break }
            guard event == CMARK_EVENT_ENTER, let child = cmark_iter_get_node(iterator) else { continue }
            switch cmark_node_get_type(child) {
            case CMARK_NODE_TEXT, CMARK_NODE_CODE:
                text.appendRaw(cmark_node_get_literal(child))
            case CMARK_NODE_SOFTBREAK, CMARK_NODE_LINEBREAK:
                text.append(" ")
            default:
                break
            }
        }
        return text.string
    }

    private static func isInTightList(_ item: Node) -> Bool {
        cmark_node_parent(item).map { cmark_node_get_list_tight($0) != 0 } ?? false
    }

    private static func isTaskItem(_ node: Node) -> Bool {
        strcmp(cmark_node_get_type_string(node), "tasklist") == 0
    }

    private static func containsTaskItem(_ list: Node) -> Bool {
        var child = cmark_node_first_child(list)
        while let item = child {
            if isTaskItem(item) { return true }
            child = cmark_node_next(item)
        }
        return false
    }

    /// The first word of a fenced code block's info string, e.g. `swift` in "```swift title=x".
    static func language(fromInfo info: UnsafePointer<CChar>?) -> String? {
        guard let info else { return nil }
        let word = String(cString: info).split(whereSeparator: \.isWhitespace).first
        return word.map(String.init)
    }

    /// Footnote labels are free text; keep IDs to characters that are safe in both `id` and `href`.
    private mutating func footnoteID(_ definition: Node) -> String {
        if let id = footnoteIDs[definition] { return id }
        let label = cmark_node_get_literal(definition).map { String(cString: $0) } ?? ""
        var id = String.UnicodeScalarView()
        for scalar in label.unicodeScalars {
            id.append(Slugger.isWordCharacter(scalar) || scalar == "-" || scalar == "_" ? scalar : "-")
        }
        footnoteIDs[definition] = String(id)
        return String(id)
    }
}
