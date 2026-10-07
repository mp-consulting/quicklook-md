# Signing & notarization

Releases are signed with a **Developer ID Application** certificate and notarized by Apple, so Gatekeeper opens them without warnings. This all happens in [release.yml](../.github/workflows/release.yml) when a GitHub Release is published. This page covers the credentials it needs and how to renew them.

## What's needed

| Item | Where to create it | Notes |
|------|--------------------|-------|
| Developer ID Application certificate | [developer.apple.com › Certificates › +](https://developer.apple.com/account/resources/certificates/add) › Developer ID › **Developer ID Application** | Not *Developer ID Installer* (that one only signs `.pkg`) and not *Apple Development*. Pick the **G2 Sub-CA** profile type. Needs the Account Holder role. |
| App Store Connect API key | [App Store Connect › Users and Access › Integrations › Team Keys](https://appstoreconnect.apple.com/access/integrations/api) | *Developer* access is enough. The `.p8` can only be downloaded once. The Issuer ID is shown at the top of that page. |

To create the certificate, generate a CSR in Keychain Access (Certificate Assistant › *Request a Certificate From a Certificate Authority*) on the Mac that will hold the key. Upload it, then double-click the downloaded `.cer`. Alternatively, Xcode › Settings › Accounts › Manage Certificates › **+** › Developer ID Application does both steps.

Check it's usable:

```sh
security find-identity -v -p codesigning   # should list "Developer ID Application: … (4HWBUF2R8D)"
```

## GitHub secrets

| Secret | Value |
|--------|-------|
| `MACOS_CERTIFICATE_P12` | `base64 -i DeveloperID.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Password chosen when exporting the `.p12` |
| `NOTARY_API_KEY` | `base64 -i AuthKey_<KEYID>.p8` |
| `NOTARY_KEY_ID` | The key's ID (also in the `.p8` file name) |
| `NOTARY_ISSUER_ID` | Issuer ID from the API keys page |

Export the `.p12` from **Keychain Access › login › My Certificates**. Right-click the *Developer ID Application* row (expand it first to confirm a private key is underneath) and choose **Export…**. Export only that row. The `security export` command can't do this from a script, because macOS requires a GUI confirmation to export a private key.

```sh
R=mp-consulting/quicklook-md
base64 -i DeveloperID.p12 | gh secret set MACOS_CERTIFICATE_P12 -R $R
gh secret set MACOS_CERTIFICATE_PASSWORD -R $R        # prompts
base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set NOTARY_API_KEY -R $R
gh secret set NOTARY_KEY_ID -R $R -b XXXXXXXXXX
gh secret set NOTARY_ISSUER_ID -R $R -b xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Keep the `.p12`, `.p8` and passwords out of the repo.

## Notarizing locally

```sh
SIGN_IDENTITY="Developer ID Application: Mickael Palma (4HWBUF2R8D)" \
TEAM_ID=4HWBUF2R8D \
NOTARY_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8 \
NOTARY_KEY_ID=XXXXXXXXXX \
NOTARY_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
scripts/build-release.sh 1.2.3
```

Check the result:

```sh
spctl -a -t open --context context:primary-signature -vv dist/QuickLook-MD-1.2.3.dmg   # source=Notarized Developer ID
xcrun stapler validate dist/QuickLook-MD-1.2.3.dmg
```

## Renewal

- **The current certificate expires on 1 February 2027.** It was issued under Apple's *Previous Sub-CA*, which expires that day. Builds released before then keep working, because they're timestamped and notarized. To release after that date, create a new Developer ID Application certificate with the **G2 Sub-CA** profile type (valid for 5 years) and update `MACOS_CERTIFICATE_P12` and `MACOS_CERTIFICATE_PASSWORD`.
- API keys don't expire. If one is revoked, generate a new one and update `NOTARY_API_KEY` and `NOTARY_KEY_ID`.

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| `No Developer ID Application identity found in MACOS_CERTIFICATE_P12` | The `.p12` holds another certificate (e.g. Apple Development) or has no private key. Run `openssl pkcs12 -in DeveloperID.p12 -legacy -nokeys \| grep subject` to see which one it holds. |
| `security: SecKeychainItemExport: The user name or passphrase you entered is not correct` | You ran `security export` from a script or terminal session that can't show the GUI prompt. Export from Keychain Access instead. |
| Notarization status `Invalid` | Run `xcrun notarytool log <submission-id> --key … --key-id … --issuer …` to see the reason. Usual causes: missing hardened runtime, no secure timestamp, or `get-task-allow` present. The release script handles all three. |
| Gatekeeper still warns after download | The ticket isn't stapled. Check with `xcrun stapler validate`. |
