import Testing
@testable import MarkdownRendering

@Suite("Blocks")
struct BlockTests {
    @Test func emptyInput() {
        #expect(render("") == "")
        #expect(render("\n\n  \n") == "")
    }

    @Test func paragraphs() {
        #expect(render("one\n\ntwo") == "<p>one</p>\n<p>two</p>\n")
    }

    @Test(arguments: 1...6)
    func headingLevels(level: Int) {
        let hashes = String(repeating: "#", count: level)
        #expect(render("\(hashes) Title") == "<h\(level) id=\"title\"><a class=\"anchor\" href=\"#title\"></a>Title</h\(level)>\n")
    }

    @Test func setextHeadings() {
        #expect(render("Title\n=====").hasPrefix("<h1 id=\"title\">"))
        #expect(render("Sub\n---").hasPrefix("<h2 id=\"sub\">"))
    }

    @Test func headingIDsAreUniqueAndIgnoreFormatting() {
        let html = render("# Hello *World*\n\n## Hello World\n\n### Hello `World`")
        #expect(html.contains("<h1 id=\"hello-world\">"))
        #expect(html.contains("<h2 id=\"hello-world-1\">"))
        #expect(html.contains("<h3 id=\"hello-world-2\">"))
        #expect(html.contains("Hello <em>World</em></h1>"))
    }

    @Test func headingTextIsEscapedAndPunctuationDroppedFromID() {
        let html = render("# a \"b\" & c")
        #expect(html.contains("id=\"a-b--c\""))
        #expect(html.contains("a &quot;b&quot; &amp; c</h1>"))
    }

    @Test func inlineHTMLInHeadingIsKeptButNotInID() {
        #expect(render("# a <c>") == "<h1 id=\"a-\"><a class=\"anchor\" href=\"#a-\"></a>a <c></h1>\n")
    }

    @Test func thematicBreak() {
        #expect(render("a\n\n***\n\nb") == "<p>a</p>\n<hr>\n<p>b</p>\n")
    }

    @Test func blockQuote() {
        #expect(render("> quote") == "<blockquote>\n<p>quote</p>\n</blockquote>\n")
        #expect(render("> outer\n>> inner").contains("<blockquote>\n<p>inner</p>\n</blockquote>\n</blockquote>"))
    }

    @Test func fencedCodeBlockWithLanguage() {
        #expect(render("```swift\nlet x = 1 < 2\n```") ==
            "<pre data-lang=\"swift\"><code class=\"language-swift\">let x = 1 &lt; 2\n</code></pre>\n")
    }

    @Test func codeBlockLanguageIsFirstWordOfInfoString() {
        #expect(render("```js title=\"a.js\"\nx\n```").hasPrefix("<pre data-lang=\"js\"><code class=\"language-js\">"))
    }

    @Test func codeBlockLanguageIsEscaped() {
        #expect(render("```a\"><b\nx\n```").contains("data-lang=\"a&quot;&gt;&lt;b\""))
    }

    @Test func codeBlockWithoutLanguage() {
        #expect(render("```\n<b>&\n```") == "<pre><code>&lt;b&gt;&amp;\n</code></pre>\n")
        #expect(render("    indented") == "<pre><code>indented\n</code></pre>\n")
    }

    @Test func htmlBlockPassesThrough() {
        #expect(render("<div align=\"center\">\n<b>hi</b>\n</div>") == "<div align=\"center\">\n<b>hi</b>\n</div>\n")
    }

    @Test func crlfLineEndings() {
        #expect(render("# Title\r\n\r\nText\r\nmore") == render("# Title\n\nText\nmore"))
    }
}

@Suite("Lists")
struct ListTests {
    @Test func tightListHasNoParagraphs() {
        #expect(render("- a\n- b") == "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n")
    }

    @Test func looseListWrapsParagraphs() {
        #expect(render("- a\n\n- b") == "<ul>\n<li><p>a</p>\n</li>\n<li><p>b</p>\n</li>\n</ul>\n")
        // One blank line between blocks of a single item also makes the list loose.
        #expect(render("- a\n\n  more\n- b").contains("<li><p>b</p>"))
    }

    @Test func orderedListStart() {
        #expect(render("1. a\n2. b").hasPrefix("<ol>\n"))
        #expect(render("3. a\n4. b").hasPrefix("<ol start=\"3\">\n"))
        #expect(render("0. a").hasPrefix("<ol start=\"0\">\n"))
    }

    @Test func nestedLists() {
        #expect(render("- a\n  - b\n- c") == "<ul>\n<li>a\n<ul>\n<li>b</li>\n</ul>\n</li>\n<li>c</li>\n</ul>\n")
    }

    @Test func taskList() {
        let html = render("- [x] done\n- [ ] todo\n- plain")
        #expect(html.hasPrefix("<ul class=\"contains-task-list\">"))
        #expect(html.contains("<li class=\"task-list-item\"><input type=\"checkbox\" disabled checked> done</li>"))
        #expect(html.contains("<li class=\"task-list-item\"><input type=\"checkbox\" disabled> todo</li>"))
        #expect(html.contains("<li>plain</li>"))
    }

    @Test func orderedTaskList() {
        #expect(render("1. [X] done").hasPrefix("<ol class=\"contains-task-list\">"))
    }

    @Test func listWithoutTasksHasNoClass() {
        #expect(!render("- a\n- b").contains("contains-task-list"))
    }
}
