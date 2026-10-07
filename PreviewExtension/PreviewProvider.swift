import Foundation
import MarkdownRendering
import QuickLookUI

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let data = try Data(contentsOf: fileURL)
        let source = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)

        // Local images are loaded while rendering and served to the preview as `cid:` attachments.
        let images = LocalImageLoader(baseDirectory: fileURL.deletingLastPathComponent())
        let html = MarkdownRendering.htmlDocument(
            from: source,
            title: fileURL.lastPathComponent,
            imageSource: images.source(for:)
        )
        let attachments = Dictionary(uniqueKeysWithValues: images.attachments.map {
            ($0.identifier, QLPreviewReplyAttachment(data: $0.data, contentType: $0.contentType))
        })

        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 1100)) { reply in
            reply.stringEncoding = .utf8
            reply.title = fileURL.lastPathComponent
            reply.attachments = attachments
            return Data(html.utf8)
        }
    }
}
