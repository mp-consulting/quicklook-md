import Foundation
import MarkdownRendering
import QuickLookUI
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    /// Images larger than this are left as-is rather than embedded in the preview.
    private static let maxImageSize = 20 * 1024 * 1024

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let data = try Data(contentsOf: fileURL)
        let source = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)

        let (attachments, sourceMap) = Self.imageAttachments(for: source, relativeTo: fileURL.deletingLastPathComponent())
        let html = MarkdownRendering.htmlDocument(
            from: source,
            title: fileURL.lastPathComponent,
            imageSource: { sourceMap[$0] ?? $0 }
        )

        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1100)) { reply in
            reply.stringEncoding = .utf8
            reply.title = fileURL.lastPathComponent
            reply.attachments = attachments
            return Data(html.utf8)
        }
    }

    /// Loads local images referenced by the document so they can be served to the preview as `cid:` attachments.
    private static func imageAttachments(
        for source: String,
        relativeTo directory: URL
    ) -> (attachments: [String: QLPreviewReplyAttachment], sourceMap: [String: String]) {
        var attachments: [String: QLPreviewReplyAttachment] = [:]
        var sourceMap: [String: String] = [:]

        for imageSource in Set(MarkdownRendering.imageSources(in: source)) {
            guard let url = localURL(for: imageSource, relativeTo: directory),
                  let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxImageSize,
                  let data = try? Data(contentsOf: url) else { continue }
            let identifier = "image-\(attachments.count).\(url.pathExtension)"
            attachments[identifier] = QLPreviewReplyAttachment(data: data, contentType: type)
            sourceMap[imageSource] = "cid:\(identifier)"
        }
        return (attachments, sourceMap)
    }

    private static func localURL(for imageSource: String, relativeTo directory: URL) -> URL? {
        if let url = URL(string: imageSource), let scheme = url.scheme {
            return scheme == "file" ? url : nil
        }
        // Strip any query or fragment, then resolve percent-escapes and relative paths.
        let path = String(imageSource.prefix { $0 != "?" && $0 != "#" })
        let decoded = path.removingPercentEncoding ?? path
        if decoded.hasPrefix("/") { return URL(fileURLWithPath: decoded) }
        if decoded.hasPrefix("~/") { return URL(fileURLWithPath: NSString(string: decoded).expandingTildeInPath) }
        return URL(fileURLWithPath: decoded, relativeTo: directory).standardizedFileURL
    }
}
