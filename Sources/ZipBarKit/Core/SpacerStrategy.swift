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
        let chevron: NSStatusItem
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
            NSStatusBar.system.removeStatusItem(entry.chevron)
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
                NSStatusBar.system.removeStatusItem(entry.chevron)
            }
            autoHideTimers.removeValue(forKey: removed)?.invalidate()
        }

        self.layout = layout
        for group in layout.groups {
            if items[group.id] == nil {
                install(group)
            } else {
                refreshChevron(for: group)
            }
        }
    }

    // MARK: - Collapse state

    public func isCollapsed(_ groupID: MenuBarGroup.ID) -> Bool {
        guard let entry = items[groupID] else { return false }
        return SpacerGeometry.isCollapsed(length: entry.separator.length)
    }

    public func setCollapsed(_ collapsed: Bool, for groupID: MenuBarGroup.ID) {
        guard let entry = items[groupID], let group = layout.group(id: groupID) else { return }
        entry.separator.length = collapsed
            ? SpacerGeometry.hidingLength(widestScreenWidth: Self.widestScreenWidth())
            : SpacerGeometry.expandedLength
        refreshChevron(for: group)
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

    private func install(_ group: MenuBarGroup) {
        let separator = NSStatusBar.system.statusItem(withLength: SpacerGeometry.expandedLength)
        // Stable autosave names let macOS remember where the user dragged
        // each separator across launches.
        separator.autosaveName = "com.zipbar.separator.\(group.id.uuidString)"
        StatusItemGlyph.apply(
            to: separator.button,
            symbolName: Self.separatorSymbol,
            fallbackText: "|",
            accessibilityDescription: "\(group.name) 구분자"
        )
        separator.button?.toolTip = "\(group.name) 구분자 — 숨길 아이콘을 이 왼쪽에 ⌘드래그하세요"

        let chevron = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        chevron.autosaveName = "com.zipbar.chevron.\(group.id.uuidString)"
        chevron.button?.target = self
        chevron.button?.action = #selector(chevronClicked(_:))
        chevron.button?.identifier = NSUserInterfaceItemIdentifier(group.id.uuidString)

        items[group.id] = GroupItems(separator: separator, chevron: chevron)
        refreshChevron(for: group)

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

    private func refreshChevron(for group: MenuBarGroup) {
        guard let entry = items[group.id] else { return }
        let collapsed = SpacerGeometry.isCollapsed(length: entry.separator.length)
        let symbol = collapsed ? group.symbolName : MenuBarGroup.expandedSymbol
        StatusItemGlyph.apply(
            to: entry.chevron.button,
            symbolName: symbol,
            fallbackText: collapsed ? "‹" : "›",
            accessibilityDescription: "\(group.name) \(collapsed ? "펴기" : "접기")"
        )
        entry.chevron.button?.toolTip = "\(group.name) — \(collapsed ? "펴기" : "접기")"
    }

    @objc private func chevronClicked(_ sender: NSStatusBarButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        toggle(id)
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

    /// Two upright bars read unambiguously as a divider at menu bar size.
    /// (`line.3.vertical`, used previously, is not a real SF Symbol.)
    nonisolated static let separatorSymbol = "pause.fill"
}
