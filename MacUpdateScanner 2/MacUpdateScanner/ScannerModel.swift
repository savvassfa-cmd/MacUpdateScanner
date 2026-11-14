import Foundation
import Combine
import AppKit

@MainActor
final class ScannerModel: ObservableObject {
    @Published var apps: [AppRecord] = []
    @Published var isScanning = false
    @Published var statusMessage = "Ready to scan"
    @Published var selectedFilter = "All"
    @Published var searchText = ""
    @Published var lastScan: Date?
    @Published var alertMessage: String?

    private let scanner = AppScanner()
    private let checker = UpdateChecker()

    var visibleApps: [AppRecord] {
        apps.filter { app in
            let matchesSearch = searchText.isEmpty || app.name.localizedCaseInsensitiveContains(searchText) || app.bundleID.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch selectedFilter {
            case "Updates": matchesFilter = app.status == .updateAvailable
            case "Up to date": matchesFilter = app.status == .upToDate
            case "Unverified": matchesFilter = app.status == .unverified || app.status == .error
            case "System": matchesFilter = app.status == .managedBySystem
            case "App Store": matchesFilter = app.status == .appStoreManaged
            default: matchesFilter = true
            }
            return matchesSearch && matchesFilter
        }
    }

    var updateCount: Int { apps.filter { $0.status == .updateAvailable }.count }
    var upToDateCount: Int { apps.filter { $0.status == .upToDate }.count }
    var unverifiedCount: Int { apps.filter { $0.status == .unverified || $0.status == .error }.count }
    var systemAppCount: Int { apps.filter { $0.status == .managedBySystem }.count }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        apps = []
        statusMessage = "Discovering applications…"
        Task {
            let discovered = await Task.detached(priority: .userInitiated) { [scanner] in
                scanner.scanInstalledApps { _ in }
            }.value
            apps = discovered
            statusMessage = "Found \(discovered.count) applications. Checking update sources…"
            for index in apps.indices {
                let snapshot = apps[index]
                apps[index].status = .checking
                statusMessage = "Checking \(snapshot.name) (\(index + 1) of \(discovered.count))…"
                if snapshot.isManagedBySystem {
                    apps[index].status = .managedBySystem
                    apps[index].details = "Apple system app — updates are delivered through macOS Software Update"
                    continue
                }
                if let result = await checker.check(snapshot) {
                    apps[index].latestVersion = result.latestVersion
                    apps[index].sourceName = result.sourceName
                    apps[index].sourceURL = result.sourceURL
                    apps[index].brewToken = result.brewToken
                    apps[index].appStoreURL = result.appStoreURL
                    if snapshot.installedVersion == "Unknown" {
                        apps[index].status = .unverified
                        apps[index].details = "A latest version was found, but the installed version could not be read"
                    } else if snapshot.installedVersion.versionCompare(to: result.latestVersion) == .orderedAscending {
                        apps[index].status = .updateAvailable
                        apps[index].details = "Version \(result.latestVersion) found via \(result.sourceName)"
                    } else {
                        apps[index].status = .upToDate
                        apps[index].details = "Verified via \(result.sourceName)"
                    }
                } else if let storeURL = snapshot.iWorkAppStoreURL {
                    // Apple iWork apps are updated through the Mac App Store.
                    // If Apple's public catalog cannot confirm a version, offer the official store
                    // page without claiming that the installed copy is up to date.
                    apps[index].status = .appStoreManaged
                    apps[index].appStoreURL = storeURL
                    apps[index].details = "Updates are managed through the Mac App Store; installed version could not be independently verified"
                } else {
                    apps[index].status = .unverified
                    apps[index].details = "No reliable public version source was found"
                }
            }
            lastScan = Date()
            isScanning = false
            statusMessage = "Scan complete — \(updateCount) update(s) available"
        }
    }

    func install(_ app: AppRecord) {
        if let token = app.brewToken {
            guard let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                alertMessage = "Homebrew was not found. Install Homebrew or use the application's official download page."
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["upgrade", "--cask", token]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                alertMessage = "Homebrew started updating \(app.name). The operation may request your Mac password in Terminal if required."
            } catch {
                alertMessage = "Could not start Homebrew: \(error.localizedDescription)"
            }
            return
        }
        if let url = app.appStoreURL ?? app.sourceURL {
            NSWorkspace.shared.open(url)
            alertMessage = "Opened the update source for \(app.name). Complete the update there."
        } else {
            alertMessage = "No installation route is available for this application."
        }
    }

    func reveal(_ app: AppRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([app.path])
    }
}
