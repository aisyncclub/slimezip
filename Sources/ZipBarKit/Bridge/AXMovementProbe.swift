import AppKit
import ApplicationServices

/// Asks whether other apps' menu bar items can be *moved* through
/// accessibility, without moving anything.
///
/// Reading the bar is settled — `AXSweepProbe` gets identity, title and frame
/// on macOS 26. Writing is the open question, and it decides the shape of the
/// product: if position is settable we can offer "put this icon in the group"
/// as a real action, and if it is not, the honest UI tells the user which
/// icon to ⌘-drag where, because macOS exposes reordering no other way.
///
/// `AXUIElementIsAttributeSettable` answers that without side effects, which
/// matters when the alternative is scattering a stranger's menu bar to find
/// out. Attributes are probed per item because status items are published by
/// their owning apps and need not agree with each other.
public struct AXMovementProbe {
    public struct Finding: Sendable {
        public let ownerName: String
        public let bundleIdentifier: String?
        public let title: String?
        public let frame: CGRect?
        /// Attribute name to whether this item reports it as writable.
        public let settable: [String: Bool]
        /// Actions the item publishes, e.g. AXPress.
        public let actions: [String]
    }

    private let messagingTimeout: Float

    public init(messagingTimeout: Float = 0.25) {
        self.messagingTimeout = messagingTimeout
    }

    /// Attributes worth asking about. Position is the one that would let us
    /// reorder; size and value are included to tell "this element rejects all
    /// writes" apart from "position specifically is read-only".
    static let attributes = [
        kAXPositionAttribute, kAXSizeAttribute, kAXValueAttribute,
    ]

    public func probe() -> (findings: [Finding], notes: [String]) {
        guard AXIsProcessTrusted() else {
            return ([], ["접근성 권한이 없습니다."])
        }

        var findings: [Finding] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy != .prohibited else { continue }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(axApp, messagingTimeout)

            var extrasValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                axApp, kAXExtrasMenuBarAttribute as CFString, &extrasValue) == .success,
                let extrasValue, CFGetTypeID(extrasValue) == AXUIElementGetTypeID()
            else { continue }
            let extras = extrasValue as! AXUIElement

            var childrenValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                extras, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                let children = childrenValue as? [AXUIElement]
            else { continue }

            for child in children {
                var settable: [String: Bool] = [:]
                for attribute in Self.attributes {
                    var flag: DarwinBoolean = false
                    let status = AXUIElementIsAttributeSettable(child, attribute as CFString, &flag)
                    settable[attribute] = (status == .success) && flag.boolValue
                }

                var actionsValue: CFArray?
                let actions = AXUIElementCopyActionNames(child, &actionsValue) == .success
                    ? (actionsValue as? [String] ?? [])
                    : []

                findings.append(
                    Finding(
                        ownerName: app.localizedName ?? "?",
                        bundleIdentifier: app.bundleIdentifier,
                        title: Self.copyString(child, kAXTitleAttribute as CFString)
                            ?? Self.copyString(child, kAXDescriptionAttribute as CFString),
                        frame: Self.copyFrame(child),
                        settable: settable,
                        actions: actions
                    )
                )
            }
        }

        findings.sort { ($0.frame?.minX ?? .greatestFiniteMagnitude) < ($1.frame?.minX ?? .greatestFiniteMagnitude) }

        let movable = findings.filter { $0.settable[kAXPositionAttribute] == true }
        var notes = ["아이템 \(findings.count)개 중 위치 쓰기 가능 \(movable.count)개."]
        if movable.isEmpty && !findings.isEmpty {
            notes.append("어떤 아이템도 AXPosition 쓰기를 허용하지 않습니다 — 순서 변경은 ⌘드래그 안내로 가야 합니다.")
        }
        return (findings, notes)
    }

    // MARK: - AX helpers

    private static func copyString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }

    private static func copyFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
