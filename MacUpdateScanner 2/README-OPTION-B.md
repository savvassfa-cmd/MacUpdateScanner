# Option B — Build the installable app remotely (no Xcode/Homebrew on your iMac)

This project includes a GitHub Actions workflow that builds the app on a hosted Intel Mac runner and packages the resulting `.app` as a ZIP. Your iMac does not need Xcode, Homebrew, or command-line developer tools to install the resulting app.

## What you need

- A GitHub account (free is sufficient for a public repository and its standard Actions usage, subject to GitHub's current limits).
- A browser to upload this project and download the build artifact.
- Your target Mac: Intel iMac, macOS Monterey 12.

## Build steps

1. Sign in to GitHub and create a **new private repository** named `MacUpdateScanner`. Do not initialize it with a README, license, or `.gitignore`.
2. On the new repository page, choose **Add file → Upload files**.
3. Extract this project ZIP on your computer. Upload the *contents* of the `MacUpdateScanner` folder, including the `.github` folder, `MacUpdateScanner.xcodeproj`, and `MacUpdateScanner` source folder. Commit the upload to the repository's default branch.
4. Open the repository's **Actions** tab. If GitHub asks you to enable Actions, enable them for this repository.
5. Select **Build MacUpdate Scanner (Intel / Monterey)** in the workflow list, click **Run workflow**, then **Run workflow** again.
6. Wait for the workflow to finish successfully. Open that workflow run and find **Artifacts** at the bottom. Download `MacUpdate-Scanner-Intel-Monterey`.
7. On your iMac, double-click the downloaded ZIP. Drag `MacUpdate Scanner.app` into `/Applications`.
8. First launch: Control-click the app and choose **Open**, then confirm **Open** if macOS displays an unidentified-developer warning. Do not disable Gatekeeper globally.
9. If scanning misses protected folders, add MacUpdate Scanner under **System Preferences → Security & Privacy → Privacy → Full Disk Access**, then quit and reopen the app.

## Build verification

The workflow explicitly targets `x86_64`, sets the deployment target to macOS 12.0, verifies the executable architecture with `lipo`, and packages the app. It uses an ad-hoc signature because no Developer ID certificate is supplied. This is not Apple notarization; Monterey may still show a first-launch security prompt.

## Important

The GitHub build has not run yet. This ZIP is a build-ready source package plus workflow, not the finished `.app`. A successful Actions run is required before an installable application artifact exists. The app's current update-source coverage and scanning behavior still need real-world testing on the target Mac.
