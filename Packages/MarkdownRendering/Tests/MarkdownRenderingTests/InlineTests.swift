import Testing
@testable import MarkdownRendering

@Suite("Inlines")
struct InlineTests {
    @Test func emphasis() {
        #expect(render("*em* _em_ **strong** __strong__ ***both***") ==
            "<p><em>em</em> <em>em</em> <strong>strong</strong> <strong>strong</strong> <em><strong>both</strong></em></p>\n")
    }

    @Test func strikethrough() {
        #expect(render("~~gone~~ ~also~") == "<p><del>gone</del> <del>also</del></p>\n")
    }

    @Test func inlineCodeIsEscaped() {
        #expect(render("`a < b && c`") == "<p><code>a &lt; b &amp;&amp; c</code></p>\n")
    }

    @Test(arguments: [
        ("a & b", "a &amp; b"),
        ("1 < 2 > 0", "1 &lt; 2 &gt; 0"),
        ("say \"hi\"", "say &quot;hi&quot;"),
        ("it's", "it's"),
        ("café 日本語 🎉", "café 日本語 🎉"),
    ])
    func textIsEscaped(input: String, expected: String) {
        #expect(render(input) == "<p>\(expected)</p>\n")
    }

    @Test func entitiesAreDecodedThenReEscaped() {
        #expect(render("&amp; &copy; &#65;") == "<p>&amp; © A</p>\n")
    }

    @Test func backslashEscapes() {
        #expect(render(#"\*not em\*"#) == "<p>*not em*</p>\n")
    }

    @Test func lineBreaks() {
        #expect(render("a  \nb") == "<p>a<br>\nb</p>\n")
        #expect(render("a\\\nb") == "<p>a<br>\nb</p>\n")
        #expect(render("a\nb") == "<p>a\nb</p>\n")
    }

    @Test func links() {
        #expect(render("[text](https://example.com)") == "<p><a href=\"https://example.com\">text</a></p>\n")
        #expect(render("[t](/a?x=1&y=2 \"A \\\"title\\\"\")") ==
            "<p><a href=\"/a?x=1&amp;y=2\" title=\"A &quot;title&quot;\">t</a></p>\n")
    }

    @Test func referenceLinks() {
        #expect(render("[text][ref]\n\n[ref]: https://example.com \"T\"") ==
            "<p><a href=\"https://example.com\" title=\"T\">text</a></p>\n")
    }

    @Test func autolinks() {
        #expect(render("<https://a.com>") == "<p><a href=\"https://a.com\">https://a.com</a></p>\n")
        #expect(render("visit https://example.com/x now").contains("<a href=\"https://example.com/x\">https://example.com/x</a>"))
        #expect(render("www.example.com").contains("<a href=\"http://www.example.com\">www.example.com</a>"))
    }

    @Test func images() {
        #expect(render("![alt *text*](a.png \"T\")") == "<p><img src=\"a.png\" alt=\"alt text\" title=\"T\"></p>\n")
        #expect(render("![](a.png)") == "<p><img src=\"a.png\" alt=\"\"></p>\n")
    }

    @Test func imageAttributesAreEscaped() {
        #expect(render("![a\"b](x.png?a=1&b=2)") == "<p><img src=\"x.png?a=1&amp;b=2\" alt=\"a&quot;b\"></p>\n")
    }

    @Test func imageInsideLink() {
        #expect(render("[![badge](b.svg)](https://ci)") == "<p><a href=\"https://ci\"><img src=\"b.svg\" alt=\"badge\"></a></p>\n")
    }

    @Test func imageSourceMapperIsCalledInOrder() {
        var seen: [String] = []
        let html = MarkdownRendering.htmlFragment(from: "![a](1.png) ![b](2.png)\n\n<img src=\"3.png\">") { source in
            seen.append(source)
            return "cid:\(source)"
        }
        #expect(seen == ["1.png", "2.png", "3.png"])
        #expect(html.contains("src=\"cid:1.png\""))
        #expect(html.contains("src=\"cid:3.png\""))
    }

    @Test func inlineHTMLPassesThrough() {
        #expect(render("press <kbd>Space</kbd>") == "<p>press <kbd>Space</kbd></p>\n")
    }
}
