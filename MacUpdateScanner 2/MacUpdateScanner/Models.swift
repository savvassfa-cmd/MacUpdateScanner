import Foundation

struct AppRecord: Identifiable {
    let id: String
    let name: String
    let bundleID: String
    let installedVersion: String
    let path: URL
    var latestVersion: String?
    var sourceName: String?
    var sourceURL: URL?
    var brewToken: String?
    var appStoreURL: URL?
    var status: UpdateStatus = .checking
    var details: String = "Not checked yet"

    var isManagedBySystem: Bool {
        let path = path.standardizedFileURL.path
        return path.hasPrefix("/System/Applications/") || path.hasPrefix("/System/Library/")
    }

    var canInstall: Bool {
        if status != .updateAvailable { return false }
        return brewToken != nil || appStoreURL != nil || sourceURL != nil
    }
}

enum UpdateStatus: String {
    case checking = "Checking"
    case managedBySystem = "Managed by macOS"
    case updateAvailable = "Update available"
    case upToDate = "Up to date"
    case unverified = "Unable to verify"
    case error = "Check failed"
}

struct UpdateResult {
    let latestVersion: String
    let sourceName: String
    let sourceURL: URL?
    let brewToken: String?
    let appStoreURL: URL?
}

extension String {
    func versionCompare(to other: String) -> ComparisonResult {
        let cleanA = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanB = other.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanA.compare(cleanB, options: [.numeric, .caseInsensitive])
    }

    var normalizedAppToken: String {
        lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
