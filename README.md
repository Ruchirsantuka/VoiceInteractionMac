# Voice Interaction Mac

Voice Interaction Mac is a small macOS menu bar app for local voice typing. It records short speech segments from the microphone, transcribes them with WhisperKit, and pastes the recognized text into whichever app currently has focus.

The app is built as a Swift Package executable and packaged into a signed `.app` bundle by `build_app.sh`.

## Features

- Local speech-to-text transcription through WhisperKit.
- Menu bar status item with start, stop, and permission controls.
- Floating control window showing current status and the last transcript.
- `F1` hotkey to start or stop listening.
- Automatic text insertion into other apps through macOS Accessibility APIs.
- Basic speech segmentation using microphone volume, silence duration, and maximum segment length.

## Requirements

- macOS 14 or newer.
- Xcode command line tools or a full Xcode install.
- Swift 6 toolchain.
- Internet access the first time dependencies and the WhisperKit model are downloaded.
- Microphone permission.
- Accessibility permission, so the app can paste transcribed text into other applications.

## Dependencies

The app uses Apple platform frameworks for the macOS UI, audio capture, permissions, menu bar integration, and text insertion:

- SwiftUI
- AppKit
- AVFoundation
- Combine

It also depends on:

- [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift), provided by `argmax-oss-swift`, for local speech transcription.

Swift Package Manager resolves the external dependency from `Package.swift` and pins the exact version in `Package.resolved`.

## Build

Build the Swift executable:

```sh
swift build
```

Build the release `.app` bundle:

```sh
./build_app.sh
```

The packaged app is written to:

```text
dist/Voice Interaction.app
```

`dist/` is ignored by git because it contains generated build output.

## Run

After packaging, open the app bundle:

```sh
open "dist/Voice Interaction.app"
```

On first launch, macOS may ask for microphone permission. The app also opens the Accessibility permission prompt. If text insertion does not work, check:

```text
System Settings > Privacy & Security > Accessibility
```

Enable Voice Interaction there, then restart the app if needed.

## Usage

1. Launch the app; listening starts automatically after permissions are granted.
2. Grant microphone and Accessibility permissions when prompted.
3. Focus any text field in another app.
4. Speak naturally; the app transcribes each speech segment and pastes it into the focused field.
5. Use `F1` or the Start/Stop control to toggle listening.

## Implementation Notes

- `VoiceTypingController` owns the app state, WhisperKit setup, hotkey handling, segmentation, transcription, and paste flow.
- `AudioCaptureService` captures microphone audio with `AVAudioEngine` and converts it to 16 kHz mono float samples for transcription.
- `AccessibilityTyper` handles trusted-access checks and text insertion into the active app.
- `StatusItemController` creates the menu bar item and popover UI.
- `ControlWindowController` manages the main control window.
- `build_app.sh` creates the `.app` bundle, generates the app icon, writes `Info.plist`, and signs the app with an ad hoc signature.

## Repository Layout

```text
Package.swift
Package.resolved
build_app.sh
Sources/
  VoiceInteractionMac/
    AppDelegate.swift
    AudioCaptureService.swift
    AccessibilityTyper.swift
    ContentView.swift
    ControlWindowController.swift
    GlobalHotKey.swift
    StatusItemController.swift
    VoiceInteractionMacApp.swift
    VoiceTypingController.swift
```

## Git Ignore Policy

The repository tracks source code, Swift package files, the build script, and documentation. It ignores local macOS files, SwiftPM build directories, Xcode user state, generated app bundles, archives, logs, and temporary files.

## Acknowledgements

Thanks to the WhisperKit and argmax-oss-swift maintainers for making local speech transcription available to Swift apps.
