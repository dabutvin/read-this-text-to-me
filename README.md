# Read This Text To Me

An iOS app with one job: give it text (or anything containing text) and it reads it aloud.

Walking around with headphones? Encounter something you want to listen to? Toss it in.

## Input Sources

- **Paste Text** — copy text, tap to hear it
- **Paste URL** — copy a link, app extracts the article text
- **Photo Library** — pick a photo, OCR extracts the text
- **Camera** — snap a photo of text

More sources coming: PDFs, Share Extension, QR codes, Siri Shortcuts, widgets.

## Architecture

Every input source is a `TextInputProvider` plugin. Adding a new one is a single file — implement the protocol, register it, done. It shows up in the UI automatically.

See [PLAN.md](PLAN.md) for the full architecture, phase plan, and CI/CD setup.

## Tech Stack

| Layer | Choice |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Min iOS | 17.0 |
| Project | XcodeGen (no .xcodeproj in repo) |
| OCR | Apple Vision (free) / OpenAI Vision (best quality) |
| TTS | AVSpeechSynthesizer (built-in) |
| CI/CD | GitHub Actions + fastlane |
| Distribution | TestFlight + App Store |

## Development

### Prerequisites

- Xcode 16+ (for local dev) or just use GitHub Actions (no laptop needed)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Build locally

```bash
xcodegen generate
open ReadThisTextToMe.xcodeproj
```

### Build from phone (no laptop)

1. Edit code on GitHub (mobile app or web)
2. Open a PR — CI builds automatically
3. Merge to main — TestFlight build ships
4. Install from TestFlight on your phone

### CI/CD Workflows

| Workflow | Trigger | Action |
|---|---|---|
| `ci.yml` | PR to main | Build + test |
| `testflight.yml` | Push to main | Build + upload to TestFlight |
| `release.yml` | Tag `v*.*.*` | Build + submit to App Store |

### Required Secrets

Set these in GitHub repo settings → Secrets:

| Secret | Purpose |
|---|---|
| `APPLE_ID` | Apple developer account |
| `TEAM_ID` | Apple Developer Team ID |
| `MATCH_PASSWORD` | Encrypts fastlane match certs |
| `MATCH_GIT_URL` | Private repo for certs/profiles |
| `APP_STORE_CONNECT_API_KEY_ID` | ASC API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | ASC API issuer |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | ASC API private key (.p8 content) |

## Adding a New Input Source

1. Create `ReadThisTextToMe/Providers/MyProvider.swift`
2. Implement `TextInputProvider`:

```swift
struct MyProvider: TextInputProvider {
    let id = "my_source"
    let displayName = "My Source"
    let icon = "star"          // SF Symbol
    let priority = 50

    func extractText() async throws -> String {
        // Your extraction logic here
        return "extracted text"
    }
}
```

3. Register in `ProviderRegistry.registerDefaults()`
4. Done — it appears in the UI automatically

## License

MIT
