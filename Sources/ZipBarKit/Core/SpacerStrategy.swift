import AppKit

/// Hides icons by inflating our own status items until their left-hand
/// neighbours fall off the display.
///
/// Costs nothing in permissions and works on every macOS from 14 through 26.
/// It cannot move or read other apps' icons, and it cannot reach anything
/// parked behind the notch — those need the bridge backend.
///
/// **Nesting semantics.** Status items are laid out right-to-left, so a
/// separator only displaces what sits to its left. With several groups the
/// separators nest: collapsing a group also conceals every group positioned
/// further left. The settings UI presents groups in that order so the
/// behaviour reads as containment rather than as a bug.
@MainActor
public final class SpacerStrategy: HidingStrategy {
    public nonisolated static let backend: BackendID = .spacer

    /// macOS 27 Golden Gate consolidated the per-item windows and length
    /// inflation stopped displacing anything. Rather than activate and
    /// silently do nothing, we decline and let the engine fall through.
    public nonisolated static func isSupported() -> Bool {
        if UserDefaults.standard.bool(forKey: forceKey) { return true }
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27
    }

    /// Escape hatch for testing the backend on an OS where we expect it to
    /// be dead: `defaults write com.zipbar.ZipBar ZipBarForceSpacerBackend -bool YES`
    nonisolated static let forceKey = "ZipBarForceSpacerBackend"

    public private(set) var capabilities = Capabilities(
        canHide: true,
        canEnumerate: false,
        canMove: false,
        canClickRemotely: false,
        canCapture: false,
        backend: .spacer,
        notes: ["아이콘 배치는 ⌘드래그로 직접 해야 합니다.",
                "노치 뒤의 아이콘은 이 방식으로 꺼낼 수 없습니다."]
    )

    public var collapseDidChange: ((MenuBarGroup.ID, Bool) -> Void)?

    private struct GroupItems {
        let separator: NSStatusItem
    }

    private var items: [MenuBarGroup.ID: GroupItems] = [:]
    private var autoHideTimers: [MenuBarGroup.ID: Timer] = [:]
    private var layout = MenuBarLayout()
    private var screenObserver: NSObjectProtocol?

    public init() {}

    deinit {
        // Timers and observers are torn down in deactivate(); this is a
        // backstop for the case where the strategy is dropped without it.
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    // MARK: - Lifecycle

    public func activate(layout: MenuBarLayout) throws {
        guard Self.isSupported() else {
            throw HidingStrategyError.unsupportedOnThisOS(.spacer)
        }
        self.layout = layout
        for group in layout.groups {
            install(group)
        }
        // A new display, or a resolution change, changes how far we have to
        // push. Recompute while staying collapsed.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.recomputeHidingLengths() }
        }
    }

    public func deactivate() {
        for timer in autoHideTimers.values { timer.invalidate() }
        autoHideTimers.removeAll()
        for entry in items.values {
            NSStatusBar.system.removeStatusItem(entry.separator)
        }
        items.removeAll()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    public func apply(layout: MenuBarLayout) {
        let incoming = Set(layout.groups.map(\.id))
        let existing = Set(items.keys)

        for removed in existing.subtracting(incoming) {
            if let entry = items.removeValue(forKey: removed) {
                NSStatusBar.system.removeStatusItem(entry.separator)
            }
            autoHideTimers.removeValue(forKey: removed)?.invalidate()
        }

        self.layout = layout
        for group in layout.groups {
            if items[group.id] == nil {
                install(group)
            }
        }
    }

    // MARK: - Collapse state

    /// Width of the separator while the user is arranging icons. Wide enough
    /// to aim a drag at, and marked so it reads as a boundary rather than as
    /// a second control.
    static let boundaryLength: CGFloat = 22

    private var boundaryVisible = false

    /// Current width of a group's separator. Exposed for tests, which
    /// otherwise cannot tell a hidden boundary from a missing one.
    func separatorLength(for groupID: MenuBarGroup.ID) -> CGFloat? {
        items[groupID]?.separator.length
    }

    public func setBoundaryVisible(_ visible: Bool) {
        boundaryVisible = visible
        for (id, entry) in items {
            guard let group = layout.group(id: id) else { continue }
            // An inflated separator is doing its real job; leave it alone.
            guard !SpacerGeometry.isCollapsed(length: entry.separator.length) else { continue }
            entry.separator.length = visible ? Self.boundaryLength : SpacerGeometry.expandedLength
            applyBoundaryGlyph(entry.separator, group: group, visible: visible)
        }
    }

    private func applyBoundaryGlyph(_ item: NSStatusItem, group: MenuBarGroup, visible: Bool) {
        guard let button = item.button else { return }
        if visible {
            StatusItemGlyph.apply(
                to: button,
                symbolName: "chevron.compact.left",
                fallbackText: "|",
                accessibilityDescription: "\(group.name) 경계"
            )
            button.toolTip = "\(group.name) 경계 — 숨길 아이콘을 이 왼쪽으로 ⌘드래그하세요"
        } else {
            button.image = nil
            button.title = ""
        }
    }

    public func isCollapsed(_ groupID: MenuBarGroup.ID) -> Bool {
        guard let entry = items[groupID] else { return false }
        return SpacerGeometry.isCollapsed(length: entry.separator.length)
    }

    public func setCollapsed(_ collapsed: Bool, for groupID: MenuBarGroup.ID, force: Bool = false) {
        guard let entry = items[groupID], let group = layout.group(id: groupID) else { return }
        // Defence in depth. `expandAll` already skips these, but any future
        // caller that opens groups in bulk would otherwise silently empty the
        // one place the user put icons to stop seeing them. `force` is the
        // deliberate way in — see `MenuBarEngine.revealAll`.
        if collapsed == false, group.behavior == .alwaysHidden, !force { return }
        entry.separator.length = collapsed
            ? SpacerGeometry.hidingLength(widestScreenWidth: Self.widestScreenWidth())
            : (boundaryVisible ? Self.boundaryLength : SpacerGeometry.expandedLength)
        applyBoundaryGlyph(entry.separator, group: group, visible: !collapsed && boundaryVisible)
        collapseDidChange?(groupID, collapsed)

        autoHideTimers.removeValue(forKey: groupID)?.invalidate()
        if !collapsed, group.autoHide, group.behavior != .alwaysHidden {
            scheduleAutoHide(for: group)
        }
    }

    // MARK: - Auto-hide

    /// One-shot timer. When it fires with the pointer still in the menu bar
    /// band we re-arm instead of collapsing, so the bar never snaps shut
    /// under the user's cursor. Costs a single point-in-rect test per fire.
    private func scheduleAutoHide(for group: MenuBarGroup) {
        let timer = Timer.scheduledTimer(withTimeInterval: group.autoHideDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if Self.isPointerInMenuBar() {
                    self.scheduleAutoHide(for: group)
                } else {
                    self.setCollapsed(true, for: group.id)
                }
            }
        }
        autoHideTimers[group.id] = timer
    }

    private static func isPointerInMenuBar() -> Bool {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            SpacerGeometry.isPointInMenuBarBand(
                location,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }
    }

    // MARK: - Status item plumbing

    /// Stable autosave names let macOS remember where the user dragged each
    /// item across launches. Built here rather than inline so `StatusItemPlacement`
    /// can address the same items before any of them exist.
    public nonisolated static func separatorAutosaveName(_ id: MenuBarGroup.ID) -> String {
        "com.zipbar.separator.\(id.uuidString)"
    }

    /// Our items in the order they must appear, left to right. The separator
    /// leads because it is the one that displaces things; everything of ours
    /// that follows it is therefore safe from its inflation.
    public nonisolated static func autosaveNames(for layout: MenuBarLayout) -> [String] {
        layout.groups.map { separatorAutosaveName($0.id) }
    }

    private func install(_ group: MenuBarGroup) {
        let separator = NSStatusBar.system.statusItem(withLength: SpacerGeometry.expandedLength)
        separator.autosaveName = Self.separatorAutosaveName(group.id)
        // No glyph: the slime is the only thing of ours the user should see.
        separator.button?.image = nil
        separator.button?.title = ""
        separator.button?.toolTip = "\(group.name) 경계 — 숨길 아이콘을 슬라임 왼쪽으로 ⌘드래그하세요"

        items[group.id] = GroupItems(separator: separator)
        applyBoundaryGlyph(separator, group: group, visible: boundaryVisible)

        // An always-hidden group is shut from the moment it exists; anything
        // the user drags into it disappears on arrival, which is the whole
        // contract. Other groups start open — see below.
        if group.behavior == .alwaysHidden {
            setCollapsed(true, for: group.id)
            return
        }

        // Start expanded, never collapsed.
        //
        // A freshly installed group is empty, so collapsing it hides nothing
        // useful — but the inflated separator still displaces whatever sits
        // to its left, and until the user has ⌘-dragged anything that means
        // our own chevron and control item. Collapsing on install made the
        // app look like it had failed to launch. Collapse is a deliberate
        // act, after the user has put icons in the group.
        setCollapsed(false, for: group.id)
    }

    private func recomputeHidingLengths() {
        let width = Self.widestScreenWidth()
        for (id, entry) in items where SpacerGeometry.isCollapsed(length: entry.separator.length) {
            entry.separator.length = SpacerGeometry.hidingLength(widestScreenWidth: width)
            _ = id
        }
    }

    private static func widestScreenWidth() -> CGFloat {
        NSScreen.screens.map(\.frame.width).max() ?? NSScreen.main?.frame.width ?? 1_440
    }

}
