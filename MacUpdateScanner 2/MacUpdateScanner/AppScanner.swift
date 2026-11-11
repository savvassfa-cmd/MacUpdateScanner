import Foundation
import AppKit

final class AppScanner {
    func scanInstalledApps(progress: @escaping (String) -> Void) -> [AppRecord] {
        let fm = FileManager.default
        var roots: [URL] = []
        let home = fm.homeDirectoryForCurrentUser
        roots.append(URL(fileURLWithPath: "/", isDirectory: true))
        roots.append(URL(fileURLWithPath: "/Applications", isDirectory: true))
        roots.append(URL(fileURLWithPath: "/System/Applications", isDirectory: true))
        roots.append(home.appendingPathComponent("Applications", isDirectory: true))
        roots.append(URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true))

        // Search mounted volumes too. The root volume is handled through the standard roots above.
        if let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsLocalKey], options: [.skipHiddenVolumes]) {
            for volume in volumes where volume.path != "/" && !volume.path.hasPrefix("/System/Volumes/") {
                roots.append(volume)
            }
        }

        var found: [String: AppRecord] = [:]
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isHiddenKey]
        for root in roots {
            guard fm.fileExists(atPath: root.path) else { continue }
            progress("Scanning \(root.path)")
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                                  options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                                  errorHandler: { _, _ in true }) else { continue }
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "app" {
                    enumerator.skipDescendants()
                    if let record = makeRecord(for: url) {
                        found[record.path.standardizedFileURL.path] = record
                    }
                    continue
                }
                let blocked = [".Spotlight-V100", ".Trashes", ".fseventsd", "System", "Library", "private", "dev", "proc", "cores", "Network", "Volumes"]
                if blocked.contains(url.lastPathComponent) { enumerator.skipDescendants() }
            }
        }
        return found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func makeRecord(for url: URL) -> AppRecord? {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return nil }
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = plist["CFBundleIdentifier"] as? String ?? ""
        let version = (plist["CFBundleShortVersionString"] as? String)
            ?? (plist["CFBundleVersion"] as? String) ?? "Unknown"
        return AppRecord(id: UUID().uuidString, name: name, bundleID: bundleID,
                         installedVersion: version, path: url,
                         latestVersion: nil, sourceName: nil, sourceURL: nil,
                         brewToken: nil, appStoreURL: nil)
    }
}
