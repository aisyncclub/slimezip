import AppKit
import ApplicationServices

/// What is actually in the menu bar right now, and which of it is hidden.
///
/// This is the answer to "표기" — the app could always hide icons, but until
/// Accessibility was granted it could not say *which* icons those were. The
/// window list reports every status item as belonging to Control Center on
/// macOS 26, so identity has to come from each app's own AX tree.
///
/// Hidden state is derived from geometry rather than from our own bookkeeping.
/// The user can ⌘-drag icons at any time without telling us, and the spacer
/// backend hides things by pushing them off the display, so where an item
/// actually sits is the only trustworthy signal.
@MainActor
public final class MenuBarInventory: ObservableObject {
    public struct Item: Identifiable, Sendable {
        public let id: String
        public let ownerName: String
        public let bundleIdentifier: String?
        public let title: String?
        public let frame: CGRect?
        public let processIdentifier: pid_t?
        /// Index within the owning app's extras menu bar, needed to press it.
        public let indexInApp: Int
        public let presence: Presence
        /// One of ZipBar's own items, which the user should not be told to move.
        public let isOurs: Bool
    }

    @Published public private(set) var items: [Item] = []
    @Published public private(set) var notes: [String] = []
    @Published public private(set) var isAuthorized = false
    @Published public private(set) var lastRefreshFailed = false
    /// Hidden icons whose title or width changed since the last sweep.
    ///
    /// macOS publishes no unread or badge state for another app's status
    /// item — the attribute probe found only the standard geometry and title
    /// set — so this is the strongest available proxy for "that app wants
    /// you". It is a change detector, and it is labelled as one everywhere it
    /// surfaces rather than being dressed up as notification support.
    @Published public private(set) var activeIDs: Set<String> = []

    /// Last seen signature per item, for the comparison above.
    private var signatures: [String: String] = [:]

    private let sweep: AXSweepProbe

    public init(sweep: AXSweepProbe = AXSweepProbe()) {
        self.sweep = sweep
    }

    public var hidden: [Item] { items.filter { $0.presence == .hidden && !$0.isOurs } }
    public var visible: [Item] { items.filter { $0.presence == .visible && !$0.isOurs } }
    /// Published but undrawn — surfaced in diagnostics, not in the icon list.
    public var notDrawn: [Item] { items.filter { $0.presence == .notDrawn && !$0.isOurs } }

    public func refresh() {
        isAuthorized = AXIsProcessTrusted()
        let result = sweep.probe()
        notes = result.notes
        lastRefreshFailed = isAuthorized && result.items.isEmpty

        let bands = Self.menuBarBands()
        var perApp: [pid_t: Int] = [:]

        var stillActive = activeIDs
        items = result.items.map { snapshot in
            let pid = snapshot.processIdentifier
            let indexInApp = pid.map { p -> Int in
                let next = perApp[p, default: 0]
                perApp[p] = next + 1
                return next
            } ?? 0

            // Signature covers what a status item can change without moving:
            // its label and how much room it takes.
            let signature = "\(snapshot.title ?? "")|\(Int(snapshot.frame?.width ?? 0))"
            if let previous = signatures[snapshot.id], previous != signature {
                stillActive.insert(snapshot.id)
            }
            signatures[snapshot.id] = signature

            return Item(
                id: snapshot.id,
                ownerName: snapshot.ownerName ?? "알 수 없는 앱",
                bundleIdentifier: snapshot.bundleIdentifier,
                title: snapshot.title,
                frame: snapshot.frame,
                processIdentifier: pid,
                indexInApp: indexInApp,
                presence: Self.classify(snapshot.frame, bands: bands),
                isOurs: snapshot.bundleIdentifier == Bundle.main.bundleIdentifier
            )
        }

        // Activity only means anything while an icon is out of sight.
        let hiddenIDs = Set(items.filter { $0.presence == .hidden }.map(\.id))
        activeIDs = stillActive.intersection(hiddenIDs)
    }

    /// Forget outstanding activity — called when the user opens the group and
    /// has therefore had the chance to see whatever changed.
    public func clearActivity() {
        activeIDs.removeAll()
    }

    /// Whether any hidden icon is flagged, which is what the slime shows.
    public var hasActivity: Bool { !activeIDs.isEmpty }

    /// Click an item where it sits. Works even on a hidden item, which is the
    /// point: a notification you cannot see is still one you may need to open.
    @discardableResult
    public func press(_ item: Item) -> Bool {
        guard let pid = item.processIdentifier else { return false }
        return sweep.press(pid: pid, index: item.indexInApp)
    }

    /// Request Accessibility, showing the system dialog that also registers
    /// the app in the Accessibility list.
    public func requestAuthorization() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    // MARK: - Geometry

    /// Where each screen's menu bar sits in the coordinate space AX reports.
    ///
    /// AX uses the Core Graphics space — origin at the top-left of the
    /// *primary* screen, y growing downward — while `NSScreen.frame` is
    /// AppKit's, with the origin at the bottom-left and y growing upward. A
    /// screen stacked above the primary therefore has a positive AppKit y and
    /// a negative CG y, and skipping the conversion put every band at y = 0
    /// where no item ever is, which classified the entire bar as hidden.
    private static func menuBarBands() -> [CGRect] {
        let screens = NSScreen.screens
        // The primary screen is the one at the AppKit origin; it defines the
        // flip. Falling back to the first screen keeps a single-display Mac
        // working if that lookup ever fails.
        let primaryHeight = (screens.first { $0.frame.origin == .zero } ?? screens.first)?
            .frame.height ?? 0
        let thickness = max(NSStatusBar.system.thickness, 24)

        return screens.map { screen in
            let frame = screen.frame
            let top = primaryHeight - (frame.origin.y + frame.height)
            return CGRect(x: frame.minX, y: top, width: frame.width, height: thickness + 8)
        }
    }

    /// Where an item stands relative to the bar.
    public enum Presence: Sendable {
        /// Real and on screen.
        case visible
        /// Real, but pushed outside every menu bar — what hiding looks like.
        case hidden
        /// Published by its app but not currently drawn. Control Center alone
        /// reports a dozen of these at zero size; they are not hidden icons
        /// and listing them as such buries the ones that are.
        case notDrawn
    }

    nonisolated static func classify(_ frame: CGRect?, bands: [CGRect]) -> Presence {
        guard let frame else { return .notDrawn }
        if frame.width <= 1 || frame.height <= 1 { return .notDrawn }
        return bands.contains { $0.intersects(frame) } ? .visible : .hidden
    }
}
