// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownRendering",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkdownRendering", targets: ["MarkdownRendering"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MarkdownRendering",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")],
            resources: [.copy("Resources/style.css")]
        ),
        .testTarget(
            name: "MarkdownRenderingTests",
            dependencies: ["MarkdownRendering"]
        ),
    ]
)
