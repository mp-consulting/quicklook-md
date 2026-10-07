import XCTest
@testable import MarkdownRendering

final class MarkdownRenderingTests: XCTestCase {
    private func render(_ markdown: String) -> String {
        MarkdownRendering.htmlFragment(from: markdown)
    }

    func testHeadingsGetUniqueIDs() {
        let html = render("# Hello World\n\n## Hello World\n")
        XCTAssertTrue(html.contains("<h1 id=\"hello-world\">"))
        XCTAssertTrue(html.contains("<h2 id=\"hello-world-1\">"))
    }

    func testInlineFormatting() {
        let html = render("**bold** *em* ~~del~~ `a<b`")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>em</em>"))
        XCTAssertTrue(html.contains("<del>del</del>"))
        XCTAssertTrue(html.contains("<code>a&lt;b</code>"))
    }

    func testCodeBlockLanguage() {
        let html = render("```swift\nlet x = 1 < 2\n```\n")
        XCTAssertTrue(html.contains("<pre data-lang=\"swift\"><code class=\"language-swift\">let x = 1 &lt; 2\n</code></pre>"))
    }

    func testTable() {
        let html = render("| a | b |\n|:-|-:|\n| 1 | 2 |\n")
        XCTAssertTrue(html.contains("<th align=\"left\">a</th>"))
        XCTAssertTrue(html.contains("<td align=\"right\">2</td>"))
    }

    func testTaskList() {
        let html = render("- [x] done\n- [ ] todo\n")
        XCTAssertTrue(html.contains("class=\"contains-task-list\""))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled checked> done"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled> todo"))
    }

    func testTightAndLooseLists() {
        XCTAssertTrue(render("- a\n- b\n").contains("<li>a</li>"))
        XCTAssertTrue(render("- a\n\n- b\n").contains("<li><p>a</p>\n</li>"))
    }

    func testAlert() {
        let html = render("> [!WARNING]\n> Be careful\n")
        XCTAssertTrue(html.contains("<div class=\"alert alert-warning\"><p class=\"alert-title\">Warning</p>"))
        XCTAssertTrue(html.contains("<p>Be careful</p>"))
        XCTAssertFalse(html.contains("[!WARNING]"))
    }

    func testPlainBlockQuote() {
        XCTAssertTrue(render("> quote\n").contains("<blockquote>\n<p>quote</p>\n</blockquote>"))
    }

    func testImagesAreRewritten() {
        let html = MarkdownRendering.htmlFragment(
            from: "![alt](a.png)\n\n<img src=\"b.png\" width=10>\n",
            imageSource: { "cid:\($0)" }
        )
        XCTAssertTrue(html.contains("<img src=\"cid:a.png\" alt=\"alt\">"))
        XCTAssertTrue(html.contains("<img src=\"cid:b.png\" width=10>"))
    }

    func testImageSourcesCollected() {
        let sources = MarkdownRendering.imageSources(in: "![x](one.png)\n\nText <img src='two.jpg'>\n")
        XCTAssertEqual(sources, ["one.png", "two.jpg"])
    }

    func testFrontMatter() {
        let (front, body) = MarkdownRendering.splitFrontMatter("---\ntitle: x\n---\n# Body\n")
        XCTAssertEqual(front, "title: x")
        XCTAssertEqual(body, "# Body\n")
        XCTAssertNil(MarkdownRendering.splitFrontMatter("# No front matter\n---\n").frontMatter)
    }

    func testDocumentIncludesStylesheet() {
        let html = MarkdownRendering.htmlDocument(from: "# Hi", title: "T<")
        XCTAssertTrue(html.contains("<title>T&lt;</title>"))
        XCTAssertTrue(html.contains("prefers-color-scheme"))
    }
}
