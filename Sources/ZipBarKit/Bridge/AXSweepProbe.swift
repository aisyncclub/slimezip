import AppKit
import ApplicationServices

/// Enumerates status items by walking every running app's own accessibility
/// tree and reading its `AXExtrasMenuBar`.
///
/// This is the technique that survives the macOS 26 window-ownership
/// regression: the *window* belongs to Control Center now, but each app still
/// publishes its own status item through its own AX element. Asking Control
/// Center directly returns only Control Center's items, so the sweep has to
/// go app by app.
///
/// Requires Accessibility permission. Without it every query returns
/// `kAXErrorAPIDisabled` and the probe reports that rather than an empty bar,
/// so the UI can prompt instead of claiming there is nothing there.
public struct AXSweepProbe: ItemProbe {
    public static let name = "AXSweep"

    /// Unresponsive apps must not stall the sweep. A quarter second is far
    /// more than a healthy app needs and short enough that a hung one costs
    /// little.
    private let messagingTimeout: Float

    public init(messagingTimeout: Float = 0.25) {
        self.messagingTimeout = messagingTimeout
    }

    public func probe() -> ProbeResult {
        guard AXIsProcessTrusted() else {
            return ProbeResult(
                backend: Self.name,
                items: [],
                notes: ["접근성 권한이 없습니다. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 허용하세요."]
            )
        }

        var items: [MenuBarItemSnapshot] = []
        var notes: [String] = []
        var appsWithExtras = 0
        var appsScanned = 0

        for app in NSWorkspace.shared.runningApplications {
            // .prohibited apps are background daemons with no UI at all.
            guard app.activationPolicy != .prohibited else { continue }
            appsScanned += 1

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(axApp, messagingTimeout)

            guard let extras = Self.copyElement(axApp, kAXExtrasMenuBarAttribute as CFString) else { continue }
            guard let children = Self.copyElements(extras, kAXChildrenAttribute as CFString), !children.isEmpty else { continue }

            appsWithExtras += 1
            for (offset, child) in children.enumerated() {
                items.append(
                    MenuBarItemSnapshot(
                        id: "ax:\(app.processIdentifier):\(offset)",
                        bundleIdentifier: app.bundleIdentifier,
                        ownerName: app.localizedName,
                        processIdentifier: app.processIdentifier,
                        title: Self.copyString(child, kAXTitleAttribute as CFString)
                            ?? Self.copyString(child, kAXDescriptionAttribute as CFString),
                        frame: Self.copyFrame(child)
                    )
                )
            }
        }

        // Order the bar the way the user sees it, so indices are meaningful.
        items.sort { ($0.frame?.minX ?? .greatestFiniteMagnitude) < ($1.frame?.minX ?? .greatestFiniteMagnitude) }
        for index in items.indices { items[index].index = index }

        notes.append("앱 \(appsScanned)개 조회, \(appsWithExtras)개가 AXExtrasMenuBar를 노출, 아이템 \(items.count)개.")
        if items.isEmpty {
            notes.append("권한은 있으나 아이템이 0개입니다 — 이 macOS에서 AX 스윕이 막혔을 수 있습니다.")
        }

        return ProbeResult(backend: Self.name, items: items, notes: notes)
    }

    /// Activate an item in place. Falls back from AXPress to AXShowMenu
    /// because status items disagree about which action they publish.
    @discardableResult
    public func press(pid: pid_t, index: Int) -> Bool {
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, messagingTimeout)
        guard let extras = Self.copyElement(axApp, kAXExtrasMenuBarAttribute as CFString),
              let children = Self.copyElements(extras, kAXChildrenAttribute as CFString),
              children.indices.contains(index)
        else { return false }

        let element = children[index]
        for action in [kAXPressAction, "AXShowMenu"] {
            if AXUIElementPerformAction(element, action as CFString) == .success { return true }
        }
        return false
    }

    // MARK: - AX helpers

    private static func copyElement(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyElements(_ element: AXUIElement, _ attribute: CFString) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }

    private static func copyString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }

    private static func copyFrame(_ element: AXUIElement) -> CGRect? {
        guard let origin = copyAXValue(element, kAXPositionAttribute as CFString, .cgPoint, CGPoint.zero),
              let size = copyAXValue(element, kAXSizeAttribute as CFString, .cgSize, CGSize.zero)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func copyAXValue<T>(
        _ element: AXUIElement,
        _ attribute: CFString,
        _ type: AXValueType,
        _ initial: T
    ) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        var result = initial
        guard AXValueGetValue(value as! AXValue, type, &result) else { return nil }
        return result
    }
}
