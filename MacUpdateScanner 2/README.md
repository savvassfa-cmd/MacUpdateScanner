# MacUpdate Scanner

A native SwiftUI macOS application project for Intel Macs running macOS Monterey 12.0 or later.

## Easiest installation route (no Xcode or Homebrew on the target iMac)

See [README-OPTION-B.md](README-OPTION-B.md). The included GitHub Actions workflow builds an Intel `x86_64` application remotely and publishes a ZIP artifact that can be downloaded and copied into `/Applications`.

## Build locally

1. Open `MacUpdateScanner.xcodeproj` in Xcode 14 or newer.
2. Select the `MacUpdateScanner` target and **My Mac** as the run destination.
3. Build and run. The project is configured for `x86_64` and a macOS 12.0 deployment target.

## What it checks

- Enumerates `.app` bundles from the startup volume, standard macOS application locations, the current user's Applications folder, and mounted volumes.
- Reads each app's bundle identifier and installed version from `Contents/Info.plist`.
- Checks a declared Sparkle `SUFeedURL` appcast when present.
- Checks Apple's public iTunes/App Store lookup catalog by bundle identifier.
- Checks installed Homebrew casks against the Homebrew Cask API when Homebrew is installed.
- Checks a small explicit GitHub Releases mapping for known bundle identifiers.
- Compares the discovered version with the installed version and distinguishes update available, up to date, and unable to verify.

## Installation behavior

- Homebrew-managed casks can be upgraded using `brew upgrade --cask <token>` (only if Homebrew is installed).
- App Store results open the corresponding App Store listing.
- Sparkle/GitHub results open the discovered download/release URL for the user to complete the update.
- The app does not silently replace application bundles. Review prompts, administrator authorization, app-specific installers, and vendor licensing flows remain under the user's control.

## Important limitations

There is no universal macOS registry of every third-party app's latest version. An app with no feed, no App Store record, no Homebrew cask match, and no known release mapping cannot be reliably classified as current or outdated. It is therefore marked **Unable to verify**, not **Up to date**. Generic developer-site scraping is not yet implemented; arbitrary websites do not expose a consistent machine-readable version format and scraping can produce false positives.

A scan of every mounted volume can take time. macOS privacy protections may prevent reading some locations; granting Full Disk Access to the built app may improve coverage. External, network, encrypted, or sleeping volumes are only scanned when mounted and accessible.

The GitHub Actions workflow builds the project on a hosted Intel macOS runner, verifies the `x86_64` architecture, and packages the app with an ad-hoc signature. It is not Developer ID signed or Apple notarized, so macOS may display a first-launch security warning. The workflow must complete successfully before an installable `.app` artifact exists.
