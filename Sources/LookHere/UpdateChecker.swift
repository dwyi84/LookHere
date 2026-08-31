import Foundation

struct ReleaseInfo {
    let latestVersion: String
    let htmlURL: URL
}

enum UpdateChecker {
    static let repoOwner = "dwyi84"
    static let repoName = "LookHere"
    static let currentVersion = "1.0.0"

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
            return ReleaseInfo(latestVersion: tag, htmlURL: url)
        } catch {
            return nil
        }
    }

    static func isNewer(_ version: String) -> Bool {
        version.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}