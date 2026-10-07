import Testing
@testable import MarkdownRendering

@Suite("Tables")
struct TableTests {
    @Test func tableStructureAndAlignment() {
        let html = render("| a | b | c | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |")
        #expect(html == """
            <table>
            <thead>
            <tr>
            <th align="left">a</th>
            <th align="center">b</th>
            <th align="right">c</th>
            <th>d</th>
            </tr>
            </thead>
            <tbody>
            <tr>
            <td align="left">1</td>
            <td align="center">2</td>
            <td align="right">3</td>
            <td>4</td>
            </tr>
            </tbody>
            </table>

            """)
    }

    @Test func headerOnlyTableHasNoBody() {
        let html = render("| a | b |\n|---|---|")
        #expect(html.contains("<thead>"))
        #expect(!html.contains("<tbody>"))
    }

    @Test func cellsContainInlines() {
        let html = render("| x |\n|---|\n| **b** `c` [l](u) \\| pipe |")
        #expect(html.contains("<td><strong>b</strong> <code>c</code> <a href=\"u\">l</a> | pipe</td>"))
    }

    @Test func shortRowsArePaddedAndExtraCellsDropped() {
        let html = render("| a | b |\n|---|---|\n| 1 |\n| 1 | 2 | 3 |")
        #expect(html.components(separatedBy: "<td").count - 1 == 4)
    }

    @Test func alignmentResetsBetweenTables() {
        let html = render("| a |\n|--:|\n| 1 |\n\n| b |\n|---|\n| 2 |")
        #expect(html.contains("<td align=\"right\">1</td>"))
        #expect(html.contains("<td>2</td>"))
    }
}

@Suite("Footnotes")
struct FootnoteTests {
    @Test func referenceAndDefinition() {
        let html = render("Text[^note].\n\n[^note]: The note.")
        #expect(html.contains("<sup class=\"footnote-ref\"><a href=\"#fn-note\" id=\"fnref-note\">1</a></sup>"))
        #expect(html.contains("<section class=\"footnotes\">\n<ol>\n<li id=\"fn-note\">\n<p>The note. <a href=\"#fnref-note\" class=\"footnote-backref\" aria-label=\"Back to reference\">↩</a></p>\n</li>\n</ol>\n</section>\n"))
    }

    @Test func numberedInReferenceOrder() {
        let html = render("A[^b] B[^a]\n\n[^a]: first defined\n[^b]: second defined")
        #expect(html.contains("id=\"fnref-b\">1</a>"))
        #expect(html.contains("id=\"fnref-a\">2</a>"))
        #expect(html.range(of: "id=\"fn-b\"")!.lowerBound < html.range(of: "id=\"fn-a\"")!.lowerBound)
    }

    @Test func eachReferenceRendersOnce() {
        let html = render("A[^x] B[^y]\n\n[^x]: one\n[^y]: two")
        #expect(html.components(separatedBy: "<sup").count - 1 == 2)
    }

    @Test func repeatedReferencesGetDistinctIDs() {
        let html = render("A[^x] B[^x]\n\n[^x]: note")
        #expect(html.components(separatedBy: "<sup").count - 1 == 2)
        #expect(html.contains("id=\"fnref-x\">1</a>"))
        #expect(html.contains("id=\"fnref-x-2\">1</a>"))
    }

    @Test func labelsAreSanitizedForIDs() {
        let html = render("A[^a.b/\"c\"]\n\n[^a.b/\"c\"]: n")
        #expect(html.contains("href=\"#fn-a-b--c-\""))
        #expect(html.contains("id=\"fn-a-b--c-\""))
    }

    @Test func backReferenceAfterNonParagraphBlock() {
        let html = render("A[^c]\n\n[^c]:\n    ```\n    code\n    ```")
        #expect(html.contains("</code></pre>\n <a href=\"#fnref-c\" class=\"footnote-backref\""))
    }

    @Test func unreferencedDefinitionsAreDropped() {
        #expect(!render("Text\n\n[^unused]: nope").contains("footnotes"))
    }
}

@Suite("Alerts")
struct AlertTests {
    @Test(arguments: Alert.allCases)
    func everyAlertKind(alert: Alert) {
        let html = render("> [!\(alert.rawValue.uppercased())]\n> Body")
        #expect(html == "<div class=\"alert alert-\(alert.rawValue)\"><p class=\"alert-title\">\(alert.title)</p>\n<p>Body</p>\n</div>\n")
    }

    @Test func markerIsCaseInsensitive() {
        #expect(render("> [!Tip]\n> x").hasPrefix("<div class=\"alert alert-tip\">"))
    }

    @Test func multipleParagraphsAndBlocks() {
        let html = render("> [!NOTE]\n> First\n>\n> - item\n>\n> Last")
        #expect(html == "<div class=\"alert alert-note\"><p class=\"alert-title\">Note</p>\n<p>First</p>\n<ul>\n<li>item</li>\n</ul>\n<p>Last</p>\n</div>\n")
    }

    @Test func markerOnItsOwnParagraph() {
        let html = render("> [!WARNING]\n>\n> Body")
        #expect(html == "<div class=\"alert alert-warning\"><p class=\"alert-title\">Warning</p>\n<p>Body</p>\n</div>\n")
    }

    @Test func markerWithTextOnSameLineIsNotAnAlert() {
        #expect(render("> [!NOTE] inline").hasPrefix("<blockquote>"))
    }

    @Test func unknownKindIsNotAnAlert() {
        let html = render("> [!DANGER]\n> x")
        #expect(html.hasPrefix("<blockquote>"))
        #expect(html.contains("[!DANGER]"))
    }

    @Test func markerElsewhereIsPlainText() {
        #expect(render("Use [!NOTE] in quotes.") == "<p>Use [!NOTE] in quotes.</p>\n")
    }

    @Test func nestedAlertInPlainQuote() {
        let html = render("> outer\n>\n> > [!TIP]\n> > inner")
        #expect(html.hasPrefix("<blockquote>\n<p>outer</p>\n<div class=\"alert alert-tip\">"))
        #expect(html.hasSuffix("</div>\n</blockquote>\n"))
    }
}
