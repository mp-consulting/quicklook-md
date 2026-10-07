# QuickLook MD

A macOS Quick Look extension that renders Markdown files (`.md`, `.markdown`) as formatted, GitHub-style HTML when you press Space in Finder.

## Features

- CommonMark + GitHub Flavored Markdown (tables with alignment, task lists, strikethrough, autolinks) via [swift-markdown](https://github.com/swiftlang/swift-markdown)
- GitHub alerts (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`)
- YAML/TOML front matter shown as a block instead of garbled text
- Local images (relative, absolute, `~/`, and raw HTML `<img>`) embedded in the preview
- Raw HTML passthrough, light and dark mode

## Install

Requires macOS 14 Sonoma or later.

1. Download `QuickLook-MD-<version>.dmg` from the [latest release](https://github.com/mp-consulting/quicklook-md/releases/latest).
2. Open it and drag **QuickLook MD** to **Applications**.
3. Launch **QuickLook MD** once. This registers the Quick Look extension with macOS.
4. Select a Markdown file in Finder and press <kbd>Space</kbd>.

If you still see plain text:

- Open **System Settings › General › Login Items & Extensions › Quick Look** and make sure **QuickLook MD** is enabled. The app's **Open Extension Settings** button takes you there.
- Reset Quick Look: `qlmanage -r && qlmanage -r cache`.

Releases are signed with a Developer ID certificate and notarized by Apple. The `.zip` contains the same app. `SHA256SUMS.txt` lists the checksums of both files.

### Uninstall

Delete **QuickLook MD** from Applications, then run `qlmanage -r`.

## Build from source

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
make install     # build Release, copy to /Applications, register the extension, reset Quick Look
make test        # run the renderer unit tests
make uninstall
make release VERSION=1.0.0   # build, sign and package into dist/ (ad-hoc signed unless SIGN_IDENTITY is set)
```

If previews still show plain text, open the app and click **Open Extension Settings**, then enable *Markdown Preview* under Quick Look.

## Layout

| Path | What |
|------|------|
| `PreviewExtension/` | Data-based Quick Look preview extension (`QLPreviewProvider`) |
| `App/` | Host app: shows a sample rendering and a shortcut to extension settings |
| `Packages/MarkdownRendering/` | Markdown → HTML renderer and stylesheet, with tests |
| `project.yml` | XcodeGen spec — edit this, not the `.xcodeproj`, Info.plists or entitlements |
| `scripts/build-release.sh` | Release build: signing, notarization, `.zip`/`.dmg` packaging and checksums |

## Releasing

Publishing a GitHub Release with a `vX.Y.Z` tag runs [release.yml](.github/workflows/release.yml). It builds the app, signs it with Developer ID, notarizes and staples it, then attaches the `.dmg`, `.zip` and `SHA256SUMS.txt` to the release. It needs these repository secrets:

| Secret | Content |
|--------|---------|
| `MACOS_CERTIFICATE_P12` | Base64 of the exported *Developer ID Application* certificate and private key (`.p12`) |
| `MACOS_CERTIFICATE_PASSWORD` | Password of that `.p12` |
| `NOTARY_API_KEY` | Base64 of the App Store Connect API key (`AuthKey_XXXX.p8`) |
| `NOTARY_KEY_ID` | ID of that key |
| `NOTARY_ISSUER_ID` | Issuer ID shown on the App Store Connect *Integrations* page |

## License

[MIT](LICENSE)
