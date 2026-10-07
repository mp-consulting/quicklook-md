import MarkdownRendering
import SwiftUI
import WebKit

@main
struct QuickLookMDApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 6) {
                    Text("QuickLook MD").font(.title2.bold())
                    Text("Select a Markdown file in Finder and press Space to preview it. If previews still show plain text, make sure the extension is enabled.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Open Extension Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                }
            }
            .padding(20)
            Divider()
            SamplePreview()
        }
    }
}

/// Renders the bundled sample with the same renderer the Quick Look extension uses.
struct SamplePreview: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let url = Bundle.main.url(forResource: "Sample", withExtension: "md")
        let source = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "# Sample missing"
        webView.loadHTMLString(MarkdownRendering.htmlDocument(from: source, title: "Sample"), baseURL: nil)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
