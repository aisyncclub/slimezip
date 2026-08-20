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
                capabilities = instance.capabilities
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

    /// Where the boundary sits, as a distance from the right edge of the
    /// screen — the same units macOS stores every status item's position in.
    ///
    /// Read from our own saved position rather than measured from the live
    /// item, because that is the number another app's stored position has to
    /// be compared against for "left of the boundary" to mean anything.
    public func boundaryPosition() -> Double? {
        guard let group = layout.groups.first else { return nil }
        let key = StatusItemPlacement.key(
            for: SpacerStrategy.separatorAutosaveName(group.id))
        return UserDefaults.standard.object(forKey: key) as? Double
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
    public func expandAll() {
        for group in layout.groups {
            strategy?.setCollapsed(false, for: group.id)
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
