import Foundation

final class UpdateChecker {
    func check(_ app: AppRecord) async -> UpdateResult? {
        if let feed = sparkleFeed(for: app.path), let result = await checkSparkle(feed: feed) {
            return result
        }
        if !app.bundleID.isEmpty, let result = await checkAppStore(bundleID: app.bundleID) {
            return result
        }
        if let result = await checkHomebrew(app: app) {
            return result
        }
        if let result = await checkKnownGitHub(app: app) {
            return result
        }
        return nil
    }

    private func sparkleFeed(for appURL: URL) -> URL? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let raw = plist["SUFeedURL"] as? String else { return nil }
        return URL(string: raw)
    }

    private func checkSparkle(feed: URL) async -> UpdateResult? {
        guard let (data, _) = try? await URLSession.shared.data(from: feed),
              let xml = String(data: data, encoding: .utf8) else { return nil }
        let parser = SparkleFeedParser()
        guard let result = parser.parse(xml: xml) else { return nil }
        return UpdateResult(latestVersion: result.version, sourceName: "Sparkle appcast",
                            sourceURL: result.downloadURL, brewToken: nil, appStoreURL: nil)
    }

    private func checkAppStore(bundleID: String) async -> UpdateResult? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [URLQueryItem(name: "bundleId", value: bundleID),
                                 URLQueryItem(name: "country", value: "gr")]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let item = results.first,
              let version = item["version"] as? String else { return nil }
        let storeURL = (item["trackViewUrl"] as? String).flatMap(URL.init(string:))
        return UpdateResult(latestVersion: version, sourceName: "Mac App Store catalog",
                            sourceURL: storeURL, brewToken: nil, appStoreURL: storeURL)
    }

    private func checkHomebrew(app: AppRecord) async -> UpdateResult? {
        guard let brew = findBrew() else { return nil }
        let output = run(brew, arguments: ["list", "--cask", "--versions"])
        let appToken = app.name.normalizedAppToken
        let match = output.split(separator: "\n").compactMap { line -> (String, String)? in
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { return nil }
            let token = String(parts[0])
            let normalized = token.normalizedAppToken
            if normalized == appToken || normalized.contains(appToken) || appToken.contains(normalized) {
                return (token, String(parts[1]))
            }
            return nil
        }.first
        guard let (token, _) = match,
              let url = URL(string: "https://formulae.brew.sh/api/cask/\(token).json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else { return nil }
        return UpdateResult(latestVersion: version, sourceName: "Homebrew Cask", sourceURL: URL(string: "https://formulae.brew.sh/cask/\(token)"),
                            brewToken: token, appStoreURL: nil)
    }

    private func checkKnownGitHub(app: AppRecord) async -> UpdateResult? {
        // Deliberately small, explicit mapping. Do not infer a GitHub project from a bundle ID.
        let repositories: [String: String] = [
            "org.videolan.vlc": "videolan/vlc",
            "com.microsoft.visual-studio-code": "microsoft/vscode",
            "com.github.wez.wezterm": "wez/wezterm",
            "com.colliderli.iina": "iina/iina"
        ]
        guard let repo = repositories[app.bundleID],
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("MacUpdateScanner/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return nil }
        let releaseURL = (json["html_url"] as? String).flatMap(URL.init(string:))
        return UpdateResult(latestVersion: tag, sourceName: "GitHub Releases", sourceURL: releaseURL,
                            brewToken: nil, appStoreURL: nil)
    }

    private func findBrew() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    @discardableResult
    private func run(_ executable: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private final class SparkleFeedParser: NSObject, XMLParserDelegate {
    private var inItem = false
    private var currentVersion: String?
    private var currentDownload: URL?
    private var found: (version: String, downloadURL: URL?)?

    func parse(xml: String) -> (version: String, downloadURL: URL?)? {
        guard let data = xml.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: data)
        parser.delegate = self
        _ = parser.parse()
        return found
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "item" { inItem = true; currentVersion = nil; currentDownload = nil }
        guard inItem else { return }
        if elementName == "enclosure" {
            if let raw = attributeDict["url"] { currentDownload = URL(string: raw) }
            currentVersion = attributeDict["sparkle:version"] ?? attributeDict["version"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Many feeds expose the version as an enclosure attribute; handled below as a fallback.
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            if let version = currentVersion, found == nil { found = (version, currentDownload) }
            inItem = false
        }
    }
}
