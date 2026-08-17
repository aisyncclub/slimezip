import Foundation
import ObjectiveC.runtime

/// Reconnaissance for a private menu-bar API.
///
/// Community reports credit BetterTouchTool and Bartender with finding a
/// non-public route that survives the macOS 26/27 changes, but the name that
/// circulates publicly — `MenuServiceBridge` — does not exist as a framework
/// on macOS 26.5; it appears to be a third-party wrapper's own type name.
/// Rather than hard-code a symbol that may not exist, this probe *searches*:
/// it dlopens candidate frameworks and reports which menu-bar-shaped
/// Objective-C classes are reachable in this process.
///
/// It never calls anything it finds. Its output is input for a human deciding
/// what Phase 2 should bind to, and an early-warning signal when an OS update
/// moves things.
public struct PrivateBridgeProbe: ItemProbe {
    public static let name = "PrivateBridgeRecon"

    /// Frameworks worth pulling in before scanning, because they are the ones
    /// that own the modern menu bar.
    private static let candidateFrameworks = [
        "/System/Library/PrivateFrameworks/ControlCenter.framework/ControlCenter",
        "/System/Library/PrivateFrameworks/SystemUIPlugin.framework/SystemUIPlugin",
        "/System/Library/PrivateFrameworks/NetworkMenusCommon.framework/NetworkMenusCommon",
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
    ]

    /// Name fragments that suggest a class deals with status items.
    private static let classNameNeedles = [
        "MenuBarItem", "MenuBarExtra", "StatusItem", "MenuService", "MenuBarAgent",
    ]

    public init() {}

    public func probe() -> ProbeResult {
        var notes: [String] = []

        // Never gate on `fileExists`: system frameworks live in the dyld
        // shared cache and have no on-disk binary, so a file check reports
        // "missing" for frameworks that dlopen loads perfectly well.
        for path in Self.candidateFrameworks {
            let name = (path as NSString).lastPathComponent
            if dlopen(path, RTLD_LAZY) != nil {
                notes.append("로드됨: \(name)")
            } else {
                let reason = dlerror().map { String(cString: $0) } ?? "알 수 없음"
                notes.append("로드 실패: \(name) — \(reason)")
            }
        }

        let matches = Self.matchingClassNames()
        if matches.isEmpty {
            notes.append("메뉴바 관련 클래스를 찾지 못했습니다.")
        } else {
            notes.append("후보 클래스 \(matches.count)개:")
            notes.append(contentsOf: matches.prefix(40).map { "  \($0)" })
            if matches.count > 40 {
                notes.append("  … 외 \(matches.count - 40)개")
            }
        }

        // Recon only — this probe never returns items, because it never calls
        // anything. Binding happens in Phase 2, after a human reviews this.
        return ProbeResult(backend: Self.name, items: [], notes: notes)
    }

    /// Every loaded Objective-C class whose name looks menu-bar related.
    ///
    /// Uses `objc_getClassList` rather than `objc_copyClassNameList`, which
    /// the Swift overlay does not expose, and `class_getName` rather than
    /// `NSStringFromClass`, which can invoke class initialisers.
    static func matchingClassNames() -> [String] {
        let expected = objc_getClassList(nil, 0)
        guard expected > 0 else { return [] }

        var classes = [AnyClass](repeating: NSObject.self, count: Int(expected))
        let actual = classes.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return objc_getClassList(AutoreleasingUnsafeMutablePointer<AnyClass>(base), expected)
        }

        var found: [String] = []
        for cls in classes.prefix(Int(actual)) {
            let name = String(cString: class_getName(cls))
            if classNameNeedles.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
                found.append(name)
            }
        }
        return found.sorted()
    }
}
