# Read This Text To Me — Project Plan

## Overview

**Read This Text To Me** is an iOS app with one job: take any text-like input and read it aloud. You're walking around with headphones, encounter something you want to listen to, and toss it into the app. Done.

---

## Design Philosophy

- **Single-purpose**: Input text → hear it spoken. No accounts, no feeds, no settings bloat.
- **Extensible inputs**: Every input source is a plugin. Adding a new one should be a single file.
- **Clean UI**: One screen. Big, obvious action. Minimal chrome.
- **No-laptop development**: The entire build/test/release cycle runs through GitHub Actions + TestFlight. PRs from your phone, builds in the cloud.

---

## Architecture

### Core Abstraction: `TextInputProvider`

Every way text enters the app implements one protocol:

```swift
protocol TextInputProvider {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get } // SF Symbol name
    var priority: Int { get } // controls display order

    func extractText() async throws -> String
}
```

Adding a new input source = one new struct conforming to `TextInputProvider`. The app discovers providers automatically via a registry.

### Input Providers (Phase 1 — MVP)

| Provider | Source | OCR needed? |
|---|---|---|
| `ClipboardTextProvider` | System clipboard (plain text) | No |
| `URLTextProvider` | Paste or share a URL → extracts article text | No |
| `ClipboardImageProvider` | Image on clipboard → OCR → text | Yes |
| `PhotoLibraryProvider` | Pick from photo library → OCR → text | Yes |
| `CameraProvider` | Take a photo → OCR → text | Yes |
| `ScreenshotProvider` | Detect screenshot via photo library | Yes |

### Input Providers (Phase 2 — Future)

| Provider | Source | Notes |
|---|---|---|
| `PDFProvider` | Pick/share a PDF | Extract text or OCR pages |
| `ShareExtensionProvider` | iOS Share Sheet | Receives URLs, text, images from any app |
| `FileProvider` | iCloud Drive / Files app | Text files, docs |
| `QRCodeProvider` | Scan QR → URL → extract text | Camera-based |
| `EmailProvider` | Forward an email | Parse email body |
| `ShortcutProvider` | Siri Shortcuts integration | Automation |
| `WidgetProvider` | Home screen widget | Quick actions |
| `LiveTextProvider` | iOS Live Text API | System OCR on images |

### Services

```
┌─────────────────────────────────────────┐
│              ReadThisTextToMe            │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │        TextInputProviders        │    │
│  │  Clipboard│URL│Photo│Camera│...  │    │
│  └──────────────┬───────────────────┘    │
│                 │                         │
│                 ▼                         │
│  ┌──────────────────────────────────┐    │
│  │        OCRService (optional)      │    │
│  │  OpenAI Vision API / Apple VN    │    │
│  └──────────────┬───────────────────┘    │
│                 │                         │
│                 ▼                         │
│  ┌──────────────────────────────────┐    │
│  │     TextProcessingService         │    │
│  │  Clean up, chunk, prepare text    │    │
│  └──────────────┬───────────────────┘    │
│                 │                         │
│                 ▼                         │
│  ┌──────────────────────────────────┐    │
│  │      SpeechService (TTS)          │    │
│  │  AVSpeechSynthesizer / OpenAI    │    │
│  └──────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

**OCRService**: Uses OpenAI's vision API (`gpt-4o`) for image-to-text. Falls back to Apple's Vision framework (`VNRecognizeTextRequest`) for offline/free OCR. User can configure preference.

**TextProcessingService**: Cleans extracted text (strip HTML, fix encoding, chunk long text). Runs between extraction and speech.

**SpeechService**: Starts with Apple's built-in `AVSpeechSynthesizer` (free, offline, good enough). Can upgrade to OpenAI TTS API for higher quality voices.

**URLExtractionService**: Fetches a URL → strips HTML → returns clean article text. Uses a readability-style parser.

### Data Flow

```
User taps input source
        │
        ▼
TextInputProvider.extractText()
        │
        ▼
    Is it text? ──yes──▶ TextProcessingService.clean()
        │                        │
        no (image)               ▼
        │               SpeechService.speak()
        ▼                        │
  OCRService.recognize()         ▼
        │                   Audio output 🔊
        ▼
TextProcessingService.clean()
        │
        ▼
SpeechService.speak()
        │
        ▼
   Audio output 🔊
```

---

## UI Design

### Main Screen (only screen)

```
┌─────────────────────────────┐
│                             │
│    Read This Text To Me     │  ← title, small
│                             │
│  ┌───────────────────────┐  │
│  │                       │  │
│  │   [extracted text      │  │
│  │    preview area]       │  │
│  │                       │  │
│  └───────────────────────┘  │
│                             │
│      advancement indicator   │  ← progress bar or wave
│                             │
│  ▶ Play    ⏸ Pause   ⏹ Stop │  ← playback controls
│                             │
│  ┌─────┐ ┌─────┐ ┌─────┐   │
│  │ 📋  │ │ 🔗  │ │ 📷  │   │  ← input source grid
│  │Paste│ │ URL │ │Photo│   │
│  └─────┘ └─────┘ └─────┘   │
│  ┌─────┐ ┌─────┐ ┌─────┐   │
│  │ 📸  │ │ 🖼️  │ │ ... │   │
│  │Cam  │ │Lib  │ │More │   │
│  └─────┘ └─────┘ └─────┘   │
│                             │
│          ⚙️ Settings         │
└─────────────────────────────┘
```

- Dark/light mode adaptive
- Large tap targets
- Haptic feedback on actions
- Text preview shows what will be read
- Playback controls appear after text is loaded
- Input source buttons are the main interaction

### Settings (minimal)

- Voice selection (system voices)
- Speech rate slider
- OpenAI API key entry
- OCR preference (OpenAI vs on-device)
- TTS preference (System vs OpenAI)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Min iOS | 17.0 |
| Project gen | XcodeGen (no .xcodeproj in repo) |
| Dependencies | Swift Package Manager |
| TTS | AVSpeechSynthesizer (built-in), OpenAI TTS API (optional) |
| OCR | OpenAI Vision API, Apple Vision framework (fallback) |
| Networking | URLSession + async/await |
| URL extraction | SwiftSoup (HTML parsing) |
| CI/CD | GitHub Actions + Apple cloud signing |
| Distribution | TestFlight (beta), App Store (release) |

---

## Project Structure

```
ReadThisTextToMe/
├── App/
│   ├── ReadThisTextToMeApp.swift          # App entry point
│   └── AppState.swift                      # Global app state
├── Models/
│   ├── TextInputProvider.swift             # Provider protocol
│   ├── ProviderRegistry.swift              # Auto-discovers providers
│   └── SpeechState.swift                   # Playback state model
├── Providers/
│   ├── ClipboardTextProvider.swift
│   ├── ClipboardImageProvider.swift
│   ├── URLTextProvider.swift
│   ├── PhotoLibraryProvider.swift
│   ├── CameraProvider.swift
│   └── ScreenshotProvider.swift
├── Services/
│   ├── OCRService.swift                    # OpenAI Vision + Apple VN
│   ├── SpeechService.swift                 # AVSpeechSynthesizer wrapper
│   ├── TextProcessingService.swift         # Text cleanup
│   ├── URLExtractionService.swift          # URL → article text
│   └── OpenAIClient.swift                  # Shared OpenAI API client
├── Views/
│   ├── MainView.swift                      # The one screen
│   ├── InputSourceGrid.swift               # Grid of input buttons
│   ├── TextPreviewView.swift               # Shows extracted text
│   ├── PlaybackControlsView.swift          # Play/pause/stop
│   └── SettingsView.swift                  # Minimal settings
├── Utilities/
│   ├── Haptics.swift
│   └── Constants.swift
└── Resources/
    └── Assets.xcassets/
```

---

## CI/CD Pipeline

### Goal: Never need Xcode on a laptop

Everything runs through GitHub Actions on macOS runners. You push code (or merge a PR) from your phone, and builds go out automatically.

### Workflows

#### 1. `ci.yml` — On every PR

```
Trigger: Pull request to main
Steps:
  1. Checkout code
  2. Install XcodeGen, generate .xcodeproj
  3. Build (xcodebuild, simulator destination, no signing)
  4. Report status on PR
```

#### 2. `testflight.yml` — On merge to main

```
Trigger: Push to main
Steps:
  1. Checkout code
  2. Install XcodeGen, generate .xcodeproj
  3. Decode App Store Connect API key from secret
  4. Archive without signing (CODE_SIGNING_REQUIRED=NO)
  5. Export IPA with -allowProvisioningUpdates (Apple cloud-signs it)
  6. Upload IPA to TestFlight via altool
  7. Clean up API key file
```

#### 3. `release.yml` — On version tag

```
Trigger: Tag v*.*.*
Steps:
  1. Checkout code
  2. Install XcodeGen, generate .xcodeproj
  3. Decode App Store Connect API key from secret
  4. Archive without signing
  5. Export IPA with cloud signing
  6. Upload IPA to App Store Connect
  7. Create GitHub Release with changelog
```

### Secrets Required (GitHub repo settings)

Uses **Apple cloud-managed signing** — no certificates or provisioning profiles to manage manually. Apple handles them automatically when you export with an API key.

| Secret | Purpose |
|---|---|
| `TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | ASC API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | ASC API issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | ASC API private key (.p8), base64-encoded |

That's it — 4 secrets total. No certificates, no provisioning profiles, no keychain manipulation.

### How cloud signing works in CI

1. `xcodebuild archive` builds the app without any code signing
2. `xcodebuild -exportArchive` is called with `-allowProvisioningUpdates` and the API key auth flags
3. Apple's cloud signing service handles certificates and provisioning profiles automatically
4. The signed IPA is uploaded to App Store Connect / TestFlight

---

## Implementation Phases

### Phase 0: Scaffold (this PR)
- [x] PLAN.md
- [x] XcodeGen `project.yml`
- [x] Core protocol and registry
- [x] Basic SwiftUI shell
- [x] GitHub Actions CI workflow
- [x] Fastlane skeleton
- [x] README

### Phase 1: MVP — Clipboard + TTS
- ClipboardTextProvider (paste text, hear it)
- SpeechService with AVSpeechSynthesizer
- Basic playback controls (play/pause/stop)
- Working CI pipeline

### Phase 2: OCR Inputs
- OpenAIClient for vision API
- OCRService
- ClipboardImageProvider
- PhotoLibraryProvider
- CameraProvider

### Phase 3: URL Extraction
- URLExtractionService (readability-style HTML → text)
- URLTextProvider
- Handle various URL types (articles, tweets, etc.)

### Phase 4: Polish
- Settings screen
- Voice selection
- Speech rate control
- Haptic feedback
- Error handling / user feedback
- Dark/light mode polish

### Phase 5: Distribution
- Create App Store Connect API key, base64-encode into GitHub Secrets
- Register bundle ID and create app in App Store Connect
- TestFlight workflow validated
- App Store submission workflow
- App Store listing (screenshots, description)

### Phase 6: Extensions
- Share Extension (receive content from any app)
- Siri Shortcuts integration
- Home screen widget
- PDF support
- OpenAI TTS as premium voice option

---

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| No .xcodeproj in repo | XcodeGen | Generated from `project.yml`, avoids merge conflicts, works with CI |
| SwiftUI over UIKit | SwiftUI | Less code, declarative, good enough for this simple UI |
| iOS 17+ minimum | Latest APIs | Live Text, modern SwiftUI, simpler codebase |
| OpenAI for OCR | GPT-4o Vision | Best accuracy, handles any image/screenshot. Apple VN as free fallback |
| System TTS first | AVSpeechSynthesizer | Free, offline, zero setup. OpenAI TTS later as upgrade |
| Protocol-based providers | TextInputProvider | Dead simple to add new input types |
| Apple cloud signing | API key + `-allowProvisioningUpdates` | No certs to manage, no laptop needed, 4 secrets total |

---

## Workflow: Adding a New Input Source

1. Create `ReadThisTextToMe/Providers/MyNewProvider.swift`
2. Implement `TextInputProvider` protocol
3. Register it in `ProviderRegistry`
4. That's it — it appears in the UI automatically

---

## Workflow: Developing from iPhone

1. Open GitHub mobile app (or use Safari)
2. Edit files / create branch
3. Open PR → CI builds automatically
4. PR checks pass → merge to main
5. Main merge → TestFlight build ships automatically
6. Open TestFlight on phone → install latest build
7. Test, iterate, repeat

For larger changes, use GitHub Codespaces or Cursor cloud agents to scaffold code, then review/merge from phone.

---

## Estimated Complexity

| Phase | Components | Risk |
|---|---|---|
| Phase 0 (Scaffold) | Project setup, protocols, CI skeleton | Low — boilerplate |
| Phase 1 (MVP) | Clipboard + TTS | Low — uses built-in APIs only |
| Phase 2 (OCR) | OpenAI integration, camera/photo access | Medium — API integration, permissions |
| Phase 3 (URL) | HTML parsing, article extraction | Medium — edge cases in HTML |
| Phase 4 (Polish) | UI refinement, settings | Low — incremental |
| Phase 5 (Distribution) | Certs, provisioning, App Store | Medium — signing config is finicky |
| Phase 6 (Extensions) | Share ext, Shortcuts, widgets | Medium — each is a mini-project |
