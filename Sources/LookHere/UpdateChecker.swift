import AppKit
import Foundation

struct ReleaseInfo {
    let version: String
    let htmlURL: URL
    let assetURL: URL?
}

enum UpdateChecker {
    static let repoOwner = "dwyi84"
    static let repoName = "LookHere"
    static let currentVersion = "1.3.2"

    static let apiURL = URL(
        string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    )!

    /// Queries the GitHub Releases API for the newest release. Returns nil on
    /// network failure or if no release is published.
    static func checkForUpdates() async -> ReleaseInfo? {
        var request = URLRequest(url: apiURL)
        request.setValue("LookHere/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let tag = json?["tag_name"] as? String,
                  let html = json?["html_url"] as? String,
                  let url = URL(string: html) else {
                return nil
            }
            let assetURL = (json?["assets"] as? [[String: Any]])?
                .compactMap { $0["browser_download_url"] as? String }
                .compactMap(URL.init(string:))
                .first { $0.pathExtension == "zip" }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            return ReleaseInfo(version: version, htmlURL: url, assetURL: assetURL)
        } catch {
            return nil
        }
    }

    static func isNewer(_ version: String) -> Bool {
        let cleaned = version.hasPrefix("v") ? String(version.dropFirst()) : version
        return cleaned.compare(currentVersion, options: .numeric) == .orderedDescending
    }

    /// Downloads the release asset zip to a temporary location.
    static func downloadAsset(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("LookHere/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    /// Replaces the running .app with the downloaded one and relaunches.
    /// A detached helper script does the swap after this process exits.
    static func installAndRelaunch(zipURL: URL) {
        let bundleURL = Bundle.main.bundleURL
        let appPath = bundleURL.path
        let appDir = bundleURL.deletingLastPathComponent().path
        let scriptPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("lookhere-update.sh")

        let script = """
        #!/bin/bash
        sleep 1
        pkill -x LookHere 2>/dev/null || true
        sleep 0.5
        rm -rf "\(appPath)"
        ditto -x -k "\(zipURL.path)" "\(appDir)"
        chmod +x "\(appPath)/Contents/MacOS/LookHere" 2>/dev/null || true
        open "\(appPath)"
        rm -f "\(zipURL.path)" "\(scriptPath)"
        exit 0
        """

        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptPath
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        try? process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }
}