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

    var iWorkAppStoreURL: URL? {
        let appStoreID: String
        switch bundleID {
        case "com.apple.iWork.Numbers", "com.apple.Numbers":
            appStoreID = "409203825"
        case "com.apple.iWork.Pages", "com.apple.Pages":
            appStoreID = "409201541"
        case "com.apple.iWork.Keynote", "com.apple.Keynote":
            appStoreID = "409183694"
        default:
            return nil
        }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    var canInstall: Bool {
        if status == .appStoreManaged { return appStoreURL != nil }
        if status != .updateAvailable { return false }
        return brewToken != nil || appStoreURL != nil || sourceURL != nil
    }
}

enum UpdateStatus: String {
    case checking = "Checking"
    case managedBySystem = "Managed by macOS"
    case appStoreManaged = "Managed by App Store"
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
        // Some apps (for example Zoom) display the numeric build in parentheses,
        // while package catalogs append it as another dotted component:
        // "7.2.5 (90525)" == "7.2.5.90525".
        func normalizedVersion(_ value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.replacingOccurrences(
                of: #"\s*\((\d+)\)"#,
                with: ".$1",
                options: .regularExpression
            )
        }
        let cleanA = normalizedVersion(self)
        let cleanB = normalizedVersion(other)
        return cleanA.compare(cleanB, options: [.numeric, .caseInsensitive])
    }

    var normalizedAppToken: String {
        lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
