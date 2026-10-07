import Foundation
import MarkdownRendering

// Renders a synthetic document that exercises every construct the renderer supports.
// Run with: swift run -c release Benchmark

func section(_ i: Int) -> String {
    """
    ## Section \(i) with *emphasis* & "quotes" <tags>

    Paragraph with **bold**, `code < 1`, [a link](https://example.com/\(i)?a=1&b=2 "title"), ~~strike~~ and an image ![alt](img/\(i % 5).png).
    Second line with text to escape: a < b && c > d. Unicode: café, naïve, 日本語, emoji 🎉. See https://example.com too.[^n\(i)]

    - item one
    - item **two**
      - nested `code`
    - [x] done task

    1. first

    2. loose second

    > [!NOTE]
    > Alert body with *formatting*.

    | Col A | Col B | Col C |
    |:------|:-----:|------:|
    | a\(i) | b | c |
    | 1 | 2 | 3 |

    ```swift
    let value = items.filter { $0 < 10 && $0 > 2 }
    print("<\\(value)>")
    ```

    <img src="raw/\(i).png" width="10">

    [^n\(i)]: Footnote \(i).

    """
}

let small = (0..<40).map(section).joined()
let large = (0..<2400).map(section).joined()

func measure(_ label: String, iterations: Int, _ body: () -> Void) {
    body() // Warm up.
    var samples: [Double] = []
    for _ in 0..<iterations {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
    }
    samples.sort()
    print("\(label.padding(toLength: 28, withPad: " ", startingAt: 0)) median \(String(format: "%8.2f", samples[samples.count / 2])) ms   min \(String(format: "%8.2f", samples[0])) ms")
}

if ProcessInfo.processInfo.environment["BENCH_PROFILE"] != nil {
    for _ in 0..<60 { _ = MarkdownRendering.htmlDocument(from: large, title: "p", imageSource: { "cid:\($0)" }) }
    exit(0)
}

for (name, markdown, iterations) in [("small", small, 200), ("large", large, 15)] {
    let kilobytes = markdown.utf8.count / 1024
    measure("\(name) (\(kilobytes) KB)", iterations: iterations) {
        _ = MarkdownRendering.htmlDocument(from: markdown, title: name, imageSource: { "cid:\($0)" })
    }
}
