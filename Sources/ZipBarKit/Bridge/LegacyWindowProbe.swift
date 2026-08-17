import AppKit
import CoreGraphics

/// Enumerates status items as windows on the status bar layer.
///
/// This is what Bartender and Ice were built on. It is **broken from macOS 26
/// onward**: the windows are still there, but every one of them reports
/// Control Center as its owner, so item-to-app attribution is impossible
/// (FB18327911).
///
/// Kept because it still works on macOS 14–15, and because when it fails it
/// fails in a recognisable way — the diagnostics report says "78 windows, all
/// attributed to Control Center", which tells a future maintainer exactly
/// which regression they are looking at.
public struct LegacyWindowProbe: ItemProbe {
    public static let name = "CGWindowList"

    /// The window layer AppKit puts status items on.
    private static let statusBarWindowLayer = 25

    public init() {}

    public func probe() -> ProbeResult {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return ProbeResult(
                backend: Self.name,
                items: [],
                notes: ["CGWindowListCopyWindowInfo가 nil을 반환했습니다 (화면 기록 권한 부재 가능)."]
            )
        }

        let statusWindows = raw.filter {
            ($0[kCGWindowLayer as String] as? Int) == Self.statusBarWindowLayer
        }

        var items: [MenuBarItemSnapshot] = []
        var ownerCounts: [String: Int] = [:]

        for window in statusWindows {
            let owner = window[kCGWindowOwnerName as String] as? String
            let pid = (window[kCGWindowOwnerPID as String] as? pid_t)
            let number = (window[kCGWindowNumber as String] as? Int) ?? items.count
            ownerCounts[owner ?? "?", default: 0] += 1

            var frame: CGRect?
            if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                frame = CGRect(
                    x: bounds["X"] ?? 0,
                    y: bounds["Y"] ?? 0,
                    width: bounds["Width"] ?? 0,
                    height: bounds["Height"] ?? 0
                )
            }

            items.append(
                MenuBarItemSnapshot(
                    id: "window:\(number)",
                    ownerName: owner,
                    processIdentifier: pid,
                    title: window[kCGWindowName as String] as? String,
                    frame: frame
                )
            )
        }

        var notes: [String] = []
        // One owner for everything is the signature of the macOS 26 regression.
        if ownerCounts.count == 1, let only = ownerCounts.first, only.value > 1 {
            notes.append(
                "\(only.value)개 윈도우가 전부 '\(only.key)' 소유로 보고됨 — "
                + "macOS 26+ 소유자 오염(FB18327911). 앱 귀속 불가."
            )
        } else if statusWindows.isEmpty {
            notes.append("상태바 레이어(25)에 윈도우가 없습니다.")
        } else {
            notes.append("소유자 분포: " + ownerCounts.map { "\($0.key)×\($0.value)" }.joined(separator: ", "))
        }

        return ProbeResult(backend: Self.name, items: items, notes: notes)
    }

    /// Whether the ownership data is trustworthy on this OS. When false, the
    /// engine must not use this probe for attribution.
    public static var attributionIsReliable: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26
    }
}
