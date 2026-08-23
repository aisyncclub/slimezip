import Foundation
import AppKit

/// What the app asks the internet about, and how rarely.
///
/// Two questions, both read-only and both anonymous:
///
///   1. The banner copy, from a JSON file this project publishes on its own
///      GitHub Pages site. Editing that file and pushing is the whole
///      deployment — installed copies pick it up on their next check, with no
///      new release and no download.
///   2. Whether a newer release exists, from the GitHub releases API. Asked of
///      the API rather than kept in the JSON file on purpose: a version number
///      written by hand drifts, which is exactly how Info.plist sat at 0.1.0
///      through three releases.
///
/// Answers are cached, so a machine that is offline shows the last thing it
/// saw rather than an error. The whole thing can be switched off, and the
/// setting is honoured before any request is made.
@MainActor
final class RemoteConfig: ObservableObject {

    static let configURL = "https://aisyncclub.github.io/slimezip/app-config.json"
    static let releasesAPI = "https://api.github.com/repos/aisyncclub/slimezip/releases/latest"
    static let releasesPage = "https://github.com/aisyncclub/slimezip/releases/latest"

    /// `defaults write com.zipbar.ZipBar com.zipbar.checkForUpdates -bool NO`
    static let enabledKey = "com.zipbar.checkForUpdates"
    private static let cachedPromoKey = "com.zipbar.promo.cached"
    private static let cachedLatestKey = "com.zipbar.latestVersion"
    private static let lastCheckKey = "com.zipbar.lastConfigCheck"

    /// Six hours. A banner is not news, and a menu bar utility waking the
    /// network more often than that is a menu bar utility people uninstall.
    private static let interval: TimeInterval = 6 * 60 * 60

    @Published private(set) var promo: PromoBanner
    @Published private(set) var latestVersion: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.promo = PromoBanner.load(from: defaults)
        self.latestVersion = defaults.string(forKey: Self.cachedLatestKey)
    }

    var isEnabled: Bool {
        defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// The running version, as the bundle reports it.
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// True only when a strictly newer release exists.
    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return Self.compare(latest, currentVersion) == .orderedDescending
    }

    /// Compares dotted numeric versions field by field.
    ///
    /// Not string comparison: "0.1.10" is newer than "0.1.9" and sorts before
    /// it alphabetically, which would tell every user on 0.1.9 that they were
    /// up to date forever.
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    /// Checks if it is due, or if the caller insists.
    func refresh(force: Bool = false) {
        guard isEnabled else { return }
        if !force {
            let last = defaults.double(forKey: Self.lastCheckKey)
            guard Date().timeIntervalSince1970 - last > Self.interval else { return }
        }
        defaults.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        fetchPromo()
        fetchLatestVersion()
    }

    private func fetchPromo() {
        get(Self.configURL) { [weak self] data in
            guard let self,
                  let payload = try? JSONDecoder().decode(ConfigPayload.self, from: data),
                  let banner = payload.promo
            else { return }
            // Cached as the raw record, so the panel reads the same shape
            // whether it came from the network or from a hand-set default.
            if let encoded = try? JSONEncoder().encode(banner),
               let text = String(data: encoded, encoding: .utf8) {
                self.defaults.set(text, forKey: Self.cachedPromoKey)
            }
            self.promo = banner
        }
    }

    private func fetchLatestVersion() {
        get(Self.releasesAPI) { [weak self] data in
            guard let self,
                  let release = try? JSONDecoder().decode(ReleasePayload.self, from: data)
            else { return }
            let version = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name
            self.defaults.set(version, forKey: Self.cachedLatestKey)
            self.latestVersion = version
        }
    }

    /// A plain GET with a short timeout and no error surface.
    ///
    /// Failures are silent by design: nobody opened this panel to be told
    /// their wifi is down, and every caller has a cached answer to fall back
    /// on. Ephemeral session so nothing is written to a URL cache on disk.
    private func get(_ string: String, then handle: @escaping (Data) -> Void) {
        guard let url = URL(string: string) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { data, response, _ in
            guard let data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200
            else { return }
            Task { @MainActor in handle(data) }
        }.resume()
    }

    private struct ConfigPayload: Decodable { let promo: PromoBanner? }
    private struct ReleasePayload: Decodable { let tag_name: String }
}

extension PromoBanner {
    /// Prefers a banner set by hand, then the last one fetched, then the copy
    /// built into the app.
    ///
    /// Hand-set wins so `defaults write` still works for testing and for
    /// anyone who wants to pin their own — a remote value that silently
    /// overwrote a local one would be indistinguishable from the setting not
    /// working.
    static func load(from defaults: UserDefaults = .standard) -> PromoBanner {
        for key in [PromoBanner.defaultsKey, "com.zipbar.promo.cached"] {
            if let raw = defaults.string(forKey: key),
               let data = raw.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(PromoBanner.self, from: data) {
                return decoded
            }
        }
        return .fallback
    }
}
