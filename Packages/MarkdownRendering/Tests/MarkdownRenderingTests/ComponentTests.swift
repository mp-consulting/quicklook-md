import Testing
@testable import MarkdownRendering

@Suite("Front matter")
struct FrontMatterTests {
    @Test func yaml() {
        let (frontMatter, body) = FrontMatter.split("---\ntitle: x\ntags: [a]\n---\n# Body\n")
        #expect(frontMatter == "title: x\ntags: [a]")
        #expect(body == "# Body\n")
    }

    @Test func toml() {
        let (frontMatter, body) = FrontMatter.split("+++\ntitle = \"x\"\n+++\nBody")
        #expect(frontMatter == "title = \"x\"")
        #expect(body == "Body")
    }

    @Test func yamlDocumentEndMarker() {
        #expect(FrontMatter.split("---\na: 1\n...\nBody").frontMatter == "a: 1")
    }

    @Test func emptyFrontMatter() {
        let (frontMatter, body) = FrontMatter.split("---\n---\nBody")
        #expect(frontMatter == "")
        #expect(body == "Body")
    }

    @Test func crlf() {
        let (frontMatter, body) = FrontMatter.split("---\r\na: 1\r\n---\r\nBody")
        #expect(frontMatter == "a: 1")
        #expect(body == "Body")
    }

    @Test func byteOrderMark() {
        #expect(FrontMatter.split("\u{FEFF}---\na: 1\n---\nBody").frontMatter == "a: 1")
        #expect(FrontMatter.split("\u{FEFF}# Title").body == "# Title")
    }

    @Test(arguments: [
        "# No front matter\n---\n",
        "---\nnever closed",
        "----\na: 1\n----\n",
        "--- not a fence\na\n---\n",
        "Text\n---\na\n---",
    ])
    func notFrontMatter(source: String) {
        #expect(FrontMatter.split(source).frontMatter == nil)
    }

    @Test func renderedAsEscapedBlock() {
        let html = MarkdownRendering.htmlFragment(from: "---\ntitle: <x>\n---\n# Hi")
        #expect(html.hasPrefix("<pre class=\"front-matter\"><code>title: &lt;x&gt;</code></pre>\n<h1 id=\"hi\">"))
    }
}

@Suite("Raw HTML images")
struct RawHTMLTests {
    private func rewrite(_ html: String) -> String {
        rewritingImageSources(in: html) { "cid:\($0)" }
    }

    @Test(arguments: [
        (#"<img src="a.png">"#, #"<img src="cid:a.png">"#),
        (#"<img src='a.png'>"#, #"<img src='cid:a.png'>"#),
        (#"<img src=a.png>"#, #"<img src=cid:a.png>"#),
        (#"<IMG SRC="a.png">"#, #"<IMG SRC="cid:a.png">"#),
        (#"<img width="10" src = "a.png" />"#, #"<img width="10" src = "cid:a.png" />"#),
        ("<img\n  alt=\"x\"\n  src=\"a.png\">", "<img\n  alt=\"x\"\n  src=\"cid:a.png\">"),
        (#"<p><img src="a.png"> and <img src="b.png"></p>"#, #"<p><img src="cid:a.png"> and <img src="cid:b.png"></p>"#),
    ])
    func rewritesSource(input: String, expected: String) {
        #expect(rewrite(input) == expected)
    }

    @Test(arguments: [
        #"<img data-src="a.png">"#,
        #"<img alt="no source">"#,
        #"<imgfoo src="a.png">"#,
        #"<image src="a.png">"#,
        #"<img src="unterminated>"#,
        "plain text",
        "",
    ])
    func leavesOtherHTMLAlone(input: String) {
        #expect(rewrite(input) == input)
    }

    @Test func unicodeIsPreserved() {
        #expect(rewrite(#"<p>café <img src="é.png"> 🎉</p>"#) == #"<p>café <img src="cid:é.png"> 🎉</p>"#)
    }
}

@Suite("Slugs")
struct SluggerTests {
    @Test(arguments: [
        ("Hello World", "hello-world"),
        ("What's new?", "whats-new"),
        ("C++ & Swift", "c--swift"),
        ("snake_case-and-dash", "snake_case-and-dash"),
        ("Café Ünïcödé", "café-ünïcödé"),
        ("日本語 見出し", "日本語-見出し"),
        ("Emoji 🎉 heading", "emoji--heading"),
        ("Version 2.0", "version-20"),
        ("", ""),
    ])
    func slug(text: String, expected: String) {
        #expect(Slugger.slug(text) == expected)
    }

    @Test func duplicatesGetSuffixes() {
        var slugger = Slugger()
        #expect(["a", "a", "b", "a"].map { slugger.uniqueSlug(for: $0) } == ["a", "a-1", "b", "a-2"])
    }
}

@Suite("HTML buffer")
struct HTMLBufferTests {
    @Test(arguments: [
        ("", ""),
        ("plain", "plain"),
        ("&<>\"", "&amp;&lt;&gt;&quot;"),
        ("a&b<c>d\"e", "a&amp;b&lt;c&gt;d&quot;e"),
        ("<<<", "&lt;&lt;&lt;"),
        ("ü & 🎉", "ü &amp; 🎉"),
    ])
    func escaping(input: String, expected: String) {
        #expect(input.htmlEscaped == expected)
    }

    @Test func escapingCStrings() {
        var buffer = HTMLBuffer()
        "x<y".withCString { buffer.appendEscaped($0) }
        buffer.appendEscaped(nil as UnsafePointer<CChar>?)
        buffer.append(42)
        #expect(buffer.string == "x&lt;y42")
    }
}

@Suite("Document")
struct DocumentTests {
    @Test func documentWrapper() {
        let html = MarkdownRendering.htmlDocument(from: "# Hi", title: "A <title> & more")
        #expect(html.hasPrefix("<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">"))
        #expect(html.contains("<title>A &lt;title&gt; &amp; more</title>"))
        #expect(html.contains("<meta name=\"color-scheme\" content=\"light dark\">"))
        #expect(html.contains("<article class=\"markdown-body\">\n<h1 id=\"hi\">"))
        #expect(html.hasSuffix("</article>\n</body>\n</html>\n"))
    }

    @Test func stylesheetIsEmbedded() {
        #expect(!MarkdownRendering.stylesheet.isEmpty)
        let html = MarkdownRendering.htmlDocument(from: "")
        #expect(html.contains(".markdown-body"))
        #expect(html.contains("prefers-color-scheme: dark"))
    }

    @Test func largeDocumentRendersCompletely() {
        let markdown = (0..<5_000).map { "## Section \($0)\n\nParagraph \($0) with **bold** text.\n" }.joined(separator: "\n")
        let html = render(markdown)
        #expect(html.contains("<h2 id=\"section-4999\">"))
        #expect(html.components(separatedBy: "<strong>").count - 1 == 5_000)
    }

    @Test func deeplyNestedInputDoesNotCrash() {
        let quotes = String(repeating: ">", count: 2_000) + " deep"
        let lists = (0..<500).map { String(repeating: "  ", count: $0) + "- item" }.joined(separator: "\n")
        #expect(render(quotes).contains("deep"))
        #expect(render(lists).contains("item"))
    }

    @Test func nulBytesAreHandled() {
        #expect(render("a\u{0}b").hasPrefix("<p>a"))
    }

    @Test func concurrentRenderingIsSafe() async {
        let markdown = "# Title\n\n| a |\n|---|\n| 1 |\n\n- [x] task\n\nText[^1]\n\n[^1]: note\n\n> [!NOTE]\n> alert"
        let expected = render(markdown)
        let results = await withTaskGroup(of: String.self) { group in
            for _ in 0..<32 { group.addTask { render(markdown) } }
            return await group.reduce(into: []) { $0.append($1) }
        }
        #expect(results.allSatisfy { $0 == expected })
    }
}
