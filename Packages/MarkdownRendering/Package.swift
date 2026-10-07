// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MarkdownRendering",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MarkdownRendering", targets: ["MarkdownRendering"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "MarkdownRendering",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            resources: [.copy("Resources/style.css")]
        ),
        .testTarget(
            name: "MarkdownRenderingTests",
            dependencies: ["MarkdownRendering"],
            exclude: ["Fixtures"]
        ),
        .executableTarget(
            name: "Benchmark",
            dependencies: ["MarkdownRendering"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
