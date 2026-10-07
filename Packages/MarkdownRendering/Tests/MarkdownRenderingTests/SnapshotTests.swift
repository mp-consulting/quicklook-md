import Foundation
import Testing
@testable import MarkdownRendering

/// Renders every `Fixtures/*.md` file and compares it with the `.html` file next to it.
/// Set `RECORD_SNAPSHOTS=1` to rewrite the expected files after an intended change, then review the diff.
@Suite("Snapshots")
struct SnapshotTests {
    static let fixturesDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")

    static var fixtures: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: fixturesDirectory.path)) ?? []
        return files.filter { $0.hasSuffix(".md") }.sorted()
    }

    @Test(arguments: fixtures)
    func matchesSnapshot(fixture: String) throws {
        let markdownURL = Self.fixturesDirectory.appendingPathComponent(fixture)
        let expectedURL = markdownURL.deletingPathExtension().appendingPathExtension("html")
        let actual = MarkdownRendering.htmlFragment(from: try String(contentsOf: markdownURL, encoding: .utf8))

        if ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil {
            try actual.write(to: expectedURL, atomically: true, encoding: .utf8)
            return
        }
        let expected = try String(contentsOf: expectedURL, encoding: .utf8)
        #expect(actual == expected, "Rendering of \(fixture) changed. Rerun with RECORD_SNAPSHOTS=1 if intended.")
    }

    @Test func fixturesExist() {
        #expect(!Self.fixtures.isEmpty)
    }
}
