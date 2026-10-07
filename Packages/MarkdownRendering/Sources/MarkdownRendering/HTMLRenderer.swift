import Foundation
import Markdown

/// Converts a Markdown AST into an HTML fragment.
struct HTMLRenderer: MarkupVisitor {
    typealias Result = String

    /// Maps an image source to the URL that should be emitted in `src`.
    var imageSource: (String) -> String

    private var usedSlugs: [String: Int] = [:]
    private var inTableHead = false
    private var columnAlignments: [Table.ColumnAlignment?] = []
    private var tightLists: [Bool] = []

    init(imageSource: @escaping (String) -> String) {
        self.imageSource = imageSource
    }

    mutating func defaultVisit(_ markup: Markup) -> String {
        visitChildren(markup)
    }

    private mutating func visitChildren(_ markup: Markup) -> String {
        var out = ""
        for child in markup.children {
            out += visit(child)
        }
        return out
    }

    // MARK: Blocks

    mutating func visitDocument(_ document: Document) -> String {
        visitChildren(document)
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let id = uniqueSlug(for: heading.plainText)
        let level = heading.level
        return "<h\(level) id=\"\(id.htmlEscaped)\"><a class=\"anchor\" href=\"#\(id.htmlEscaped)\"></a>\(visitChildren(heading))</h\(level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        // Inside tight list items, paragraphs render without <p> like GitHub does.
        if paragraph.parent is ListItem, tightLists.last == true {
            return visitChildren(paragraph)
        }
        return "<p>\(visitChildren(paragraph))</p>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        if let alert = Alert(blockQuote) {
            var body = ""
            for (index, child) in blockQuote.children.enumerated() {
                if index == 0, let paragraph = child as? Paragraph {
                    // Drop the "[!NOTE]" marker and the line break that follows it.
                    let rest = Array(paragraph.children.dropFirst(paragraph.childCount > 1 && paragraph.child(at: 1) is SoftBreak ? 2 : 1))
                    let inner = rest.map { visit($0) }.joined()
                    if !inner.isEmpty { body += "<p>\(inner)</p>\n" }
                } else {
                    body += visit(child)
                }
            }
            return "<div class=\"alert alert-\(alert.rawValue)\"><p class=\"alert-title\">\(alert.title)</p>\n\(body)</div>\n"
        }
        return "<blockquote>\n\(visitChildren(blockQuote))</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let code = codeBlock.code.htmlEscaped
        if let language = codeBlock.language?.split(separator: " ").first, !language.isEmpty {
            let lang = String(language).htmlEscaped
            return "<pre data-lang=\"\(lang)\"><code class=\"language-\(lang)\">\(code)</code></pre>\n"
        }
        return "<pre><code>\(code)</code></pre>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        rewritingImageSources(in: html.rawHTML, using: imageSource)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        return "<ol\(start)\(taskListClass(orderedList))>\n\(visitListItems(orderedList))</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul\(taskListClass(unorderedList))>\n\(visitListItems(unorderedList))</ul>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        guard let checkbox = listItem.checkbox else {
            return "<li>\(visitChildren(listItem))</li>\n"
        }
        let checked = checkbox == .checked ? " checked" : ""
        return "<li class=\"task-list-item\"><input type=\"checkbox\" disabled\(checked)> \(visitChildren(listItem))</li>\n"
    }

    mutating func visitTable(_ table: Table) -> String {
        columnAlignments = table.columnAlignments
        var out = "<table>\n"
        inTableHead = true
        out += "<thead>\n<tr>\n\(visitChildren(table.head))</tr>\n</thead>\n"
        inTableHead = false
        if !table.body.isEmpty {
            out += "<tbody>\n\(visit(table.body))</tbody>\n"
        }
        return out + "</table>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        "<tr>\n\(visitChildren(tableRow))</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        guard tableCell.colspan > 0, tableCell.rowspan > 0 else { return "" }
        let index = tableCell.indexInParent
        let tag = inTableHead ? "th" : "td"
        var attributes = ""
        if index < columnAlignments.count, let alignment = columnAlignments[index] {
            let value: String
            switch alignment {
            case .left: value = "left"
            case .center: value = "center"
            case .right: value = "right"
            }
            attributes += " align=\"\(value)\""
        }
        if tableCell.colspan > 1 { attributes += " colspan=\"\(tableCell.colspan)\"" }
        if tableCell.rowspan > 1 { attributes += " rowspan=\"\(tableCell.rowspan)\"" }
        return "<\(tag)\(attributes)>\(visitChildren(tableCell))</\(tag)>\n"
    }

    // MARK: Inlines

    mutating func visitText(_ text: Text) -> String {
        text.string.htmlEscaped
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(visitChildren(emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(visitChildren(strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(visitChildren(strikethrough))</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(inlineCode.code.htmlEscaped)</code>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        rewritingImageSources(in: inlineHTML.rawHTML, using: imageSource)
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        let href = (link.destination ?? "").htmlEscaped
        let title = link.title.map { " title=\"\($0.htmlEscaped)\"" } ?? ""
        return "<a href=\"\(href)\"\(title)>\(visitChildren(link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = imageSource(image.source ?? "").htmlEscaped
        let alt = image.plainText.htmlEscaped
        let title = image.title.map { " title=\"\($0.htmlEscaped)\"" } ?? ""
        return "<img src=\"\(src)\" alt=\"\(alt)\"\(title)>"
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> String {
        "<code>\((symbolLink.destination ?? "").htmlEscaped)</code>"
    }

    // MARK: Helpers

    private mutating func visitListItems(_ list: Markup) -> String {
        tightLists.append(isTight(list))
        defer { tightLists.removeLast() }
        return visitChildren(list)
    }

    /// A list is loose if any of its items, or any blocks within an item, are separated by a blank line.
    private func isTight(_ list: Markup) -> Bool {
        let items = Array(list.children)
        for (index, item) in items.enumerated() {
            let blocks = Array(item.children)
            for (a, b) in zip(blocks, blocks.dropFirst()) where isSeparatedByBlankLine(a, b) {
                return false
            }
            if index + 1 < items.count, let last = blocks.last, isSeparatedByBlankLine(last, items[index + 1]) {
                return false
            }
        }
        return true
    }

    private func isSeparatedByBlankLine(_ a: Markup, _ b: Markup) -> Bool {
        guard let end = a.range?.upperBound.line, let start = b.range?.lowerBound.line else { return false }
        return start - end > 1
    }

    private func taskListClass(_ list: Markup) -> String {
        list.children.contains { ($0 as? ListItem)?.checkbox != nil } ? " class=\"contains-task-list\"" : ""
    }

    private mutating func uniqueSlug(for text: String) -> String {
        let base = text.lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_" }
            .map { $0 == " " ? "-" : String($0) }
            .joined()
        let count = usedSlugs[base, default: 0]
        usedSlugs[base] = count + 1
        return count == 0 ? base : "\(base)-\(count)"
    }
}

/// GitHub-style alerts: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`.
enum Alert: String, CaseIterable {
    case note, tip, important, warning, caution

    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    init?(_ blockQuote: BlockQuote) {
        guard let paragraph = blockQuote.child(at: 0) as? Paragraph,
              let text = paragraph.child(at: 0) as? Text else { return nil }
        let marker = text.string.trimmingCharacters(in: .whitespaces).lowercased()
        guard marker.hasPrefix("[!"), marker.hasSuffix("]"),
              let alert = Alert(rawValue: String(marker.dropFirst(2).dropLast())) else { return nil }
        self = alert
    }
}

extension StringProtocol {
    var htmlEscaped: String {
        var out = ""
        out.reserveCapacity(count)
        for character in self {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(character)
            }
        }
        return out
    }
}
