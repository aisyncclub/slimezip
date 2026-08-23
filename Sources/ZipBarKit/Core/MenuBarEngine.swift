import AppKit
import Combine

/// Single source of truth for groups, collapse state and what the OS is
/// currently letting us do.
///
/// The engine owns strategy selection: it walks a priority list of backends,
/// asks each whether it works here, and activates the first that says yes.
/// If none do, `capabilities` reports `.degraded` and the UI says so plainly
/// instead of offering controls that quietly fail.
@MainActor
public final class MenuBarEngine: ObservableObject {
    @Published public private(set) var layout: MenuBarLayout
    @Published public private(set) var capabilities: Capabilities = .degraded
    /// Mirrors each group's collapse state for SwiftUI to observe.
    @Published public private(set) var collapseState: [MenuBarGroup.ID: Bool] = [:]

    private var strategy: (any HidingStrategy)?
    private let store: ProfileStore

    /// Backends in preference order. Phase 2 inserts the MenuServiceBridge
    /// strategy ahead of the spacer so macOS 27 machines pick it up
    /// automatically, with no change to anything above this line.
    private let candidates: [any HidingStrategy.Type]

    public init(
        store: ProfileStore = ProfileStore(),
        candidates: [any HidingStrategy.Type] = [SpacerStrategy.self]
    ) {
        self.store = store
        self.candidates = candidates
        self.layout = store.load()
    }

    // MARK: - Lifecycle

    public func start() {
        for candidate in candidates where candidate.isSupported() {
            guard let instance = makeStrategy(candidate) else { continue }
            do {
                try instance.activate(layout: layout)
                instance.collapseDidChange = { [weak self] id, collapsed in
                    self?.collapseState[id] = collapsed
                }
                strategy = instance
                capabilities = Self.withAccessibility(instance.capabilities)
                syncCollapseState()
                return
            } catch {
                instance.deactivate()
            }
        }
        capabilities = Capabilities(
            backend: .degraded,
            notes: ["현재 macOS \(Self.osVersionString())에서 동작하는 백엔드를 찾지 못했습니다."]
        )
    }

    /// Folds in what the accessibility permission makes possible.
    ///
    /// The strategy's own table described the spacer mechanism and nothing
    /// else, so the diagnostics page reported enumeration, moving and remote
    /// clicking as unavailable while the panel was listing forty-six icons by
    /// name and restarting apps to move them. A page that contradicts the
    /// window next to it is worse than no page.
    ///
    /// Read at the moment it is asked rather than cached at launch: the user
    /// can grant the permission while the app is running, and on first launch
    /// they usually do.
    static func withAccessibility(_ base: Capabilities) -> Capabilities {
        var merged = base
        let trusted = AXIsProcessTrusted()
        merged.canEnumerate = trusted
        // Moving is real but indirect: we rewrite the position macOS has
        // stored for the icon, which it reads when that app next starts.
        merged.canMove = trusted
        merged.canClickRemotely = trusted
        if trusted {
            merged.notes.insert("아이콘을 옮기려면 그 앱을 한 번 재시작해야 합니다. "
                                + "처음 한 번뿐이고, 그 뒤로는 즉시 감춰지고 꺼내집니다.",
                                at: 0)
        } else {
            merged.notes.insert("손쉬운 사용 권한이 꺼져 있습니다. 숨기기는 되지만 "
                                + "어느 아이콘이 어느 앱 것인지 읽을 수 없어 목록이 비어 보입니다.",
                                at: 0)
        }
        return merged
    }

    /// One group's separator and where it sits.
    public struct Boundary: Sendable {
        public let groupID: MenuBarGroup.ID
        public let name: String
        public let behavior: MenuBarGroup.Behavior
        /// Distance from the right edge of the screen — the same units macOS
        /// stores every status item's position in, so another app's stored
        /// position can be compared against it directly.
        public let position: Double
    }

    /// Every boundary, leftmost first.
    ///
    /// Sorted by actual position rather than by the order groups appear in
    /// the layout: the user can ⌘-drag a separator past another one, and the
    /// arrangement on screen is what decides which zone an icon falls into.
    /// Reading stored positions rather than measuring live items keeps this
    /// in the one coordinate system that comparisons are valid in.
    public func boundaries() -> [Boundary] {
        layout.groups.compactMap { group -> Boundary? in
            let key = StatusItemPlacement.key(
                for: SpacerStrategy.separatorAutosaveName(group.id))
            guard let position = UserDefaults.standard.object(forKey: key) as? Double
            else { return nil }
            return Boundary(
                groupID: group.id, name: group.name,
                behavior: group.behavior, position: position)
        }
        .sorted { $0.position > $1.position }
    }

    /// The boundary icons are moved across when there is only one group —
    /// the common case, and the one the icon list's single button uses.
    public func boundaryPosition() -> Double? {
        boundaries().last?.position
    }

    /// Reveals the drag boundary while the user is arranging icons.
    public func setBoundaryVisible(_ visible: Bool) {
        strategy?.setBoundaryVisible(visible)
    }

    public func stop() {
        strategy?.deactivate()
        strategy = nil
    }

    // MARK: - Layout editing

    public func addGroup(named name: String) {
        var updated = layout
        updated.groups.append(MenuBarGroup(name: name))
        commit(updated)
    }

    public func removeGroup(id: MenuBarGroup.ID) {
        var updated = layout
        updated.groups.removeAll { $0.id == id }
        commit(updated)
    }

    public func update(_ group: MenuBarGroup) {
        var updated = layout
        guard let index = updated.groups.firstIndex(where: { $0.id == group.id }) else { return }
        updated.groups[index] = group
        commit(updated)
    }

    /// Reorder groups. Matches SwiftUI's `onMove` semantics without pulling
    /// SwiftUI into the kit, which stays UI-framework free so it can be
    /// exercised from the probe CLI and from tests.
    public func moveGroups(fromOffsets source: IndexSet, toOffset destination: Int) {
        var updated = layout
        let moving = source.sorted().map { updated.groups[$0] }
        for index in source.sorted(by: >) {
            updated.groups.remove(at: index)
        }
        let insertion = destination - source.filter { $0 < destination }.count
        updated.groups.insert(contentsOf: moving, at: min(max(insertion, 0), updated.groups.count))
        commit(updated)
    }

    private func commit(_ updated: MenuBarLayout) {
        layout = updated
        store.save(updated)
        strategy?.apply(layout: updated)
        syncCollapseState()
    }

    // MARK: - Collapse control

    public func toggle(_ groupID: MenuBarGroup.ID) {
        strategy?.toggle(groupID)
        syncCollapseState()
    }

    public func setCollapsed(_ collapsed: Bool, for groupID: MenuBarGroup.ID) {
        strategy?.setCollapsed(collapsed, for: groupID)
        syncCollapseState()
    }

    /// Reveal everything the current backend is able to reveal.
    /// Opens every group the user is allowed to open.
    ///
    /// An `alwaysHidden` group is excluded by name: it exists to hold icons
    /// the user has decided never to look at, so a general "show everything"
    /// must not drag them back out. Only `setCollapsed(false:)` aimed at that
    /// group by id opens it.
    public func expandAll() {
        for group in layout.groups where group.behavior != .alwaysHidden {
            strategy?.setCollapsed(false, for: group.id)
        }
        syncCollapseState()
    }

    /// Autosave names of everything ZipBar puts in the bar, ours to move.
    public func ownAutosaveNames(controlName: String) -> [String] {
        SpacerStrategy.autosaveNames(for: layout) + [controlName]
    }

    /// Where our items should sit after a nudge, or nil if nothing moves.
    ///
    /// Computed separately from applying it because the write has to land
    /// in the gap after the old items are gone and before the new ones are
    /// made. Removing a status item makes macOS clear its stored position,
    /// so a value written first is simply erased — the same trap that made
    /// Outlook overwrite a pending move on the way out.
    public func plannedOwnPositions(by delta: Double, controlName: String) -> [(String, Double)]? {
        let names = ownAutosaveNames(controlName: controlName)
        let defaults = UserDefaults.standard
        let current = names.map { name -> Double in
            defaults.object(forKey: StatusItemPlacement.key(for: name)) as? Double ?? 0
        }
        let width = StatusItemPlacement.widestScreenWidth()
        guard SelfPlacement.canShift(positions: current, by: delta,
                                     widestScreenWidth: width) else { return nil }

        let moved = SelfPlacement.shifted(positions: current, by: delta,
                                          widestScreenWidth: width)
        return Array(zip(names, moved))
    }

    /// Writes positions previously planned. Call only with our items removed.
    public func applyOwnPositions(_ plan: [(String, Double)]) {
        for (name, position) in plan {
            UserDefaults.standard.set(position, forKey: StatusItemPlacement.key(for: name))
        }
    }

    /// Removes the group items, leaving the bar without them.
    public func teardownItems() {
        strategy?.deactivate()
        strategy = nil
    }

    /// Whether a nudge in this direction is available.
    public func canShiftOwnItems(by delta: Double, controlName: String) -> Bool {
        let defaults = UserDefaults.standard
        let current = ownAutosaveNames(controlName: controlName).map { name -> Double in
            defaults.object(forKey: StatusItemPlacement.key(for: name)) as? Double ?? 0
        }
        return SelfPlacement.canShift(positions: current, by: delta,
                                      widestScreenWidth: StatusItemPlacement.widestScreenWidth())
    }

    /// Builds the group items again, picking up whatever positions are
    /// stored right now.
    public func buildItems(restoringCollapsed collapsed: [MenuBarGroup.ID]) {
        start()
        for id in collapsed { strategy?.setCollapsed(true, for: id) }
        syncCollapseState()
    }

    /// Groups that are shut, so a rebuild can put them back the way they were.
    public var collapsedGroupIDs: [MenuBarGroup.ID] {
        layout.groups.filter { collapseState[$0.id] == true }.map(\.id)
    }

    /// Whether the groups a click can actually open are currently shut.
    ///
    /// Always-hidden groups are excluded on purpose: they are shut by
    /// definition and never open on a toggle, so counting them made this
    /// permanently true. The button then read "펼치기" forever and pressing it
    /// re-expanded an already-open group — a control that looked broken while
    /// behaving exactly as written.
    public var isToggleableCollapsed: Bool {
        layout.groups.contains {
            $0.behavior != .alwaysHidden && collapseState[$0.id] == true
        }
    }

    /// Whether there is anything a toggle can act on at all.
    public var hasToggleableGroup: Bool {
        layout.groups.contains { $0.behavior != .alwaysHidden }
    }

    /// Opens every group, including the always-hidden one.
    ///
    /// The deliberate exception to `expandAll`. A group set to always-hidden
    /// must not open by accident — that is the whole reason to put an icon
    /// there — but "never, under any circumstance" is a different promise, and
    /// a worse one: it makes the icons unreachable without dismantling the
    /// group. This is the way in, and it is only ever reached by an explicit
    /// gesture the user has to know about.
    public func revealAll() {
        for group in layout.groups {
            strategy?.setCollapsed(false, for: group.id, force: true)
        }
        syncCollapseState()
    }

    public func collapseAll() {
        for group in layout.groups {
            strategy?.setCollapsed(true, for: group.id)
        }
        syncCollapseState()
    }

    private func syncCollapseState() {
        guard let strategy else {
            collapseState = [:]
            return
        }
        collapseState = Dictionary(
            uniqueKeysWithValues: layout.groups.map { ($0.id, strategy.isCollapsed($0.id)) }
        )
    }

    private func makeStrategy(_ type: any HidingStrategy.Type) -> (any HidingStrategy)? {
        // Backends are constructed through this switch rather than a generic
        // initialiser requirement, which keeps the protocol free of `init()`
        // and lets future strategies take dependencies.
        switch type {
        case is SpacerStrategy.Type:
            return SpacerStrategy()
        default:
            return nil
        }
    }

    static func osVersionString() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
}
