import Foundation
import UniformTypeIdentifiers

/// An image file loaded from disk so it can be embedded in a preview.
public struct ImageAttachment: Equatable, Sendable {
    public let identifier: String
    public let data: Data
    public let contentType: UTType
}

/// Resolves image sources found in a Markdown document to local files and loads them, so a preview can
/// serve them as attachments (`cid:` URLs) instead of reading the file system.
public final class LocalImageLoader {
    public let baseDirectory: URL
    public let maxFileSize: Int
    public private(set) var attachments: [ImageAttachment] = []

    private var resolved: [String: String] = [:]

    public init(baseDirectory: URL, maxFileSize: Int = 20 * 1024 * 1024) {
        self.baseDirectory = baseDirectory
        self.maxFileSize = maxFileSize
    }

    /// Returns `cid:<identifier>` for a loadable local image, or the source unchanged otherwise
    /// (remote URLs, data URLs, missing or oversized files, non-images).
    public func source(for imageSource: String) -> String {
        if let cached = resolved[imageSource] { return cached }
        let result = load(imageSource).map { "cid:\($0.identifier)" } ?? imageSource
        resolved[imageSource] = result
        return result
    }

    private func load(_ imageSource: String) -> ImageAttachment? {
        guard let url = Self.fileURL(for: imageSource, relativeTo: baseDirectory),
              let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxFileSize,
              let data = try? Data(contentsOf: url) else { return nil }
        let attachment = ImageAttachment(
            identifier: "image-\(attachments.count).\(url.pathExtension.lowercased())",
            data: data,
            contentType: type
        )
        attachments.append(attachment)
        return attachment
    }

    /// Maps an image source to a file URL: relative and absolute paths, `~/` paths and `file:` URLs.
    /// Returns `nil` for anything that isn't local, such as `https:` or `data:` URLs.
    static func fileURL(for imageSource: String, relativeTo directory: URL) -> URL? {
        let trimmed = imageSource.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let scheme = url.scheme {
            return scheme.lowercased() == "file" ? url.standardizedFileURL : nil
        }
        // Drop any query or fragment, then decode percent-escapes such as %20.
        let path = String(trimmed.prefix { $0 != "?" && $0 != "#" })
        let decoded = path.removingPercentEncoding ?? path
        if decoded.hasPrefix("/") { return URL(fileURLWithPath: decoded).standardizedFileURL }
        if decoded.hasPrefix("~/") { return URL(fileURLWithPath: NSString(string: decoded).expandingTildeInPath).standardizedFileURL }
        // Appending (rather than `relativeTo:`) works whether or not `directory` has a trailing slash.
        return directory.appendingPathComponent(decoded).standardizedFileURL
    }
}
