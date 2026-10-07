import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MarkdownRendering

@Suite("Local images")
struct LocalImageLoaderTests {
    /// A temporary directory with `doc/`, `doc/img/a.png`, `doc/my image.png`, `shared.jpg` and `doc/notes.txt`.
    final class Fixture {
        let root: URL
        let documentDirectory: URL
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("LocalImageLoaderTests-\(UUID().uuidString)")
            documentDirectory = root.appendingPathComponent("doc")
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: documentDirectory.appendingPathComponent("img"), withIntermediateDirectories: true)
            try pngData.write(to: documentDirectory.appendingPathComponent("img/a.png"))
            try pngData.write(to: documentDirectory.appendingPathComponent("my image.png"))
            try Data([0xFF, 0xD8, 0xFF]).write(to: root.appendingPathComponent("shared.jpg"))
            try Data("text".utf8).write(to: documentDirectory.appendingPathComponent("notes.txt"))
        }

        deinit {
            try? FileManager.default.removeItem(at: root)
        }

        func loader(maxFileSize: Int = 20 * 1024 * 1024) -> LocalImageLoader {
            LocalImageLoader(baseDirectory: documentDirectory, maxFileSize: maxFileSize)
        }
    }

    @Test(arguments: [
        "img/a.png",
        "./img/a.png",
        "img/../img/a.png",
        "img/a.png?raw=true",
        "img/a.png#fragment",
        "my%20image.png",
        "my image.png",
        "../shared.jpg",
    ])
    func loadsLocalImages(source: String) throws {
        let fixture = try Fixture()
        let loader = fixture.loader()
        #expect(loader.source(for: source).hasPrefix("cid:image-0."))
        #expect(loader.attachments.count == 1)
    }

    @Test func absolutePathsAndFileURLs() throws {
        let fixture = try Fixture()
        let path = fixture.root.appendingPathComponent("shared.jpg").path
        let loader = fixture.loader()
        #expect(loader.source(for: path) == "cid:image-0.jpg")
        #expect(loader.source(for: URL(fileURLWithPath: path).absoluteString).hasPrefix("cid:"))
    }

    @Test func attachmentContents() throws {
        let fixture = try Fixture()
        let loader = fixture.loader()
        _ = loader.source(for: "img/a.png")
        let attachment = try #require(loader.attachments.first)
        #expect(attachment.identifier == "image-0.png")
        #expect(attachment.data == fixture.pngData)
        #expect(attachment.contentType == .png)
    }

    @Test(arguments: [
        "https://example.com/a.png",
        "http://example.com/a.png",
        "data:image/png;base64,iVBORw0KGgo=",
        "img/missing.png",
        "notes.txt",
        "img",
        "",
        "   ",
    ])
    func leavesNonLocalOrInvalidSourcesUnchanged(source: String) throws {
        let fixture = try Fixture()
        let loader = fixture.loader()
        #expect(loader.source(for: source) == source)
        #expect(loader.attachments.isEmpty)
    }

    @Test func skipsFilesOverTheSizeLimit() throws {
        let fixture = try Fixture()
        let loader = fixture.loader(maxFileSize: 4)
        #expect(loader.source(for: "img/a.png") == "img/a.png")
        #expect(loader.attachments.isEmpty)
    }

    @Test func repeatedSourcesShareOneAttachment() throws {
        let fixture = try Fixture()
        let loader = fixture.loader()
        let first = loader.source(for: "img/a.png")
        #expect(loader.source(for: "img/a.png") == first)
        #expect(loader.source(for: "../shared.jpg") == "cid:image-1.jpg")
        #expect(loader.attachments.map(\.identifier) == ["image-0.png", "image-1.jpg"])
    }

    @Test func baseDirectoryWithOrWithoutTrailingSlash() {
        let withSlash = LocalImageLoader.fileURL(for: "a.png", relativeTo: URL(fileURLWithPath: "/docs/", isDirectory: true))
        let withoutSlash = LocalImageLoader.fileURL(for: "a.png", relativeTo: URL(string: "file:///docs")!)
        #expect(withSlash?.path == "/docs/a.png")
        #expect(withoutSlash?.path == "/docs/a.png")
    }

    @Test func resolvesTildePaths() {
        let url = LocalImageLoader.fileURL(for: "~/Pictures/a.png", relativeTo: URL(fileURLWithPath: "/tmp"))
        #expect(url?.path == NSString(string: "~/Pictures/a.png").expandingTildeInPath)
    }

    @Test func worksEndToEndWithTheRenderer() throws {
        let fixture = try Fixture()
        let loader = fixture.loader()
        let html = MarkdownRendering.htmlFragment(
            from: "![a](img/a.png)\n\n<img src=\"../shared.jpg\">\n\n![remote](https://x.com/r.png)",
            imageSource: loader.source(for:)
        )
        #expect(html.contains("<img src=\"cid:image-0.png\" alt=\"a\">"))
        #expect(html.contains("<img src=\"cid:image-1.jpg\">"))
        #expect(html.contains("<img src=\"https://x.com/r.png\" alt=\"remote\">"))
        #expect(loader.attachments.count == 2)
    }
}
