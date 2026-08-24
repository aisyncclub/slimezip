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
        /// Stable across launches, unlike `id`, which embeds a process id.
        public let preferenceKey: String
        /// Distance from the right edge of its screen, in the same units as
        /// `MenuBarEngine.Boundary.position`. nil when the item is not drawn.
        /// This is what makes "which side of which separator" answerable.
        public let position: Double?
        /// The position macOS has on file for this icon, read from the owning
        /// app's own preferences. Survives being pushed off-screen, which the
        /// live frame does not.
        public let storedPosition: Double?
    }

    /// An icon sitting somewhere the user did not ask it to be.
    ///
    /// The app cannot fix these itself, so each one carries the gesture that
    /// would: naming the two or three icons that are out of place is the
    /// useful half of a job macOS reserves for the user's own hands.
    public struct Misplaced: Identifiable, Sendable {
        public var id: String { item.preferenceKey }
        public let item: Item
        public let desired: IconPreferenceStore.Desired

        /// What the user has to do about it.
        public var instruction: String {
            switch desired {
            case .hidden: return L("슬라임 왼쪽으로 ⌘드래그")
            case .visible: return L("슬라임 오른쪽으로 ⌘드래그")
            }
        }
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
    private let preferences: IconPreferenceStore
    private let arranger: MenuBarArranger
    private let restarter: AppRestarter
    private let pendingStore: PendingMoveStore

    public init(
        sweep: AXSweepProbe = AXSweepProbe(),
        preferences: IconPreferenceStore = IconPreferenceStore(),
        arranger: MenuBarArranger = MenuBarArranger(),
        restarter: AppRestarter = AppRestarter(),
        pendingStore: PendingMoveStore = PendingMoveStore()
    ) {
        self.sweep = sweep
        self.preferences = preferences
        self.arranger = arranger
        self.restarter = restarter
        self.pendingStore = pendingStore
    }

    // MARK: - Moving

    /// Whether this icon can be moved for the user.
    ///
    /// Needs a bundle identifier to address the app's preferences, and must
    /// not be one of ours — moving our own boundary or slime through this
    /// path would fight `StatusItemPlacement`, which already owns their order.
    public func canMove(_ item: Item) -> Bool {
        item.bundleIdentifier != nil && !item.isOurs
    }

    /// Rewrites where macOS remembers this icon, so it lands on the requested
    /// side the next time its app starts. The move is recorded on disk until
    /// it is seen to have taken effect, so the wait survives the window
    /// closing and undo keeps working hours later.
    @discardableResult
    public func move(
        _ item: Item, to side: MenuBarArranger.Side, boundaryPosition: Double
    ) -> Bool {
        guard canMove(item),
              let bundle = item.bundleIdentifier,
              let plan = arranger.plan(
                bundleIdentifier: bundle,
                ownerName: item.ownerName,
                indexInApp: item.indexInApp,
                side: side,
                boundaryPosition: boundaryPosition),
              case .some(let previous) = arranger.apply(plan)
        else { return false }

        pendingStore.set(
            PendingMoveStore.Record(
                bundleIdentifier: bundle,
                positionKey: plan.key,
                previousValue: previous,
                targetValue: plan.targetPosition,
                side: side == .hidden ? .hidden : .visible),
            for: item.preferenceKey)
        // The stated preference follows the move, so the icon does not
        // immediately show up as out of place against its own arrangement.
        setDesired(side == .hidden ? .hidden : .visible, for: item)
        objectWillChange.send()
        return true
    }

    /// The moves still waiting for their app to restart.
    public var pendingMoves: [String: PendingMoveStore.Record] {
        pendingStore.all()
    }

    public func pendingMove(for item: Item) -> PendingMoveStore.Record? {
        pendingStore.record(for: item.preferenceKey)
    }

    /// Cancels a waiting move: puts the overwritten value back — removing the
    /// key entirely when the app had never stored one — and drops the record.
    public func cancelMove(for item: Item) {
        guard let record = pendingStore.record(for: item.preferenceKey) else { return }
        let plan = MenuBarArranger.Plan(
            bundleIdentifier: record.bundleIdentifier,
            ownerName: item.ownerName,
            key: record.positionKey,
            currentPosition: nil,
            targetPosition: 0,
            side: record.side == .hidden ? .hidden : .visible)
        arranger.revert(plan, to: record.previousValue)
        setDesired(nil, for: item)
        pendingStore.remove(for: item.preferenceKey)
        objectWillChange.send()
    }

    /// Apps whose menu bar items we can rewrite but must not restart.
    ///
    /// On macOS 26 the system draws Wi-Fi, Bluetooth, Battery, Sound and the
    /// rest through Control Center. Their stored positions live in Control
    /// Center's preferences and take our writes like anyone else's — the value
    /// we wrote for Battery is still sitting there — but quitting the process
    /// that draws half the menu bar to make one icon move is not a trade this
    /// app gets to make on the user's behalf. Left alone, the write applies
    /// when that agent next starts, which in practice means the next login.
    public static let systemManagedBundles: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.TextInputMenuAgent",
        "com.apple.Spotlight",
    ]

    /// Whether this icon belongs to one of those agents.
    public func isSystemManaged(_ item: Item) -> Bool {
        guard let bundle = item.bundleIdentifier else { return false }
        return Self.systemManagedBundles.contains(bundle)
    }

    /// A written position is theoretical until its app restarts.
    ///
    /// False for system agents: not because the move is already applied, but
    /// because there is no restart on offer. Their pending moves wait for the
    /// next login instead of sitting behind a button that cannot work.
    public func needsRestart(_ item: Item) -> Bool {
        guard let bundle = item.bundleIdentifier, !isSystemManaged(item) else { return false }
        return restarter.isRunning(bundle)
    }

    public func restart(_ item: Item, completion: @escaping (AppRestarter.Outcome) -> Void) {
        guard let bundle = item.bundleIdentifier else {
            completion(.notRunning)
            return
        }
        restartApp(bundle, completion: completion)
    }

    /// Restarts one app and applies every move waiting on it.
    ///
    /// Per app, not per icon. Restarting once per moved icon meant an app that
    /// publishes two status items — Claude does — was quit and relaunched
    /// twice for a single trip through the panel, which is most of what
    /// "재시작을 계속 해야 한다" was describing. One quit now settles all of
    /// that app's pending moves at once.
    public func restartApp(
        _ bundle: String, completion: @escaping (AppRestarter.Outcome) -> Void
    ) {
        guard !Self.systemManagedBundles.contains(bundle) else {
            completion(.notRunning)
            return
        }
        let waiting = pendingStore.all().values.filter { $0.bundleIdentifier == bundle }
        restarter.restart(bundle, beforeRelaunch: { [weak self] in
            // Written here, after the app has exited, because some apps save
            // their live position on the way out and overwrite ours. Outlook
            // does; Magnet does not — measured both ways. Writing in the gap
            // between quit and launch is the only moment that holds for both.
            guard let self else { return }
            for record in waiting {
                self.arranger.write(record.targetValue,
                                    to: record.positionKey,
                                    in: record.bundleIdentifier)
            }
        }, completion: { [weak self] outcome in
            if outcome == .restarted { self?.refresh() }
            completion(outcome)
        })
    }

    /// The apps that have moves waiting on a restart, each listed once.
    public func appsAwaitingRestart(among items: [Item]) -> [(bundle: String, name: String, count: Int)] {
        var order: [String] = []
        var names: [String: String] = [:]
        var counts: [String: Int] = [:]
        for item in items {
            guard let bundle = item.bundleIdentifier,
                  pendingMove(for: item) != nil,
                  needsRestart(item) else { continue }
            if counts[bundle] == nil { order.append(bundle); names[bundle] = item.ownerName }
            counts[bundle, default: 0] += 1
        }
        return order.map { ($0, names[$0] ?? $0, counts[$0] ?? 0) }
    }

    // MARK: - Preferences

    public func desired(for item: Item) -> IconPreferenceStore.Desired? {
        preferences.desired(for: item.preferenceKey)
    }

    public func setDesired(_ desired: IconPreferenceStore.Desired?, for item: Item) {
        preferences.set(desired, for: item.preferenceKey)
        objectWillChange.send()
    }

    /// Icons whose current side of the boundary disagrees with the user's
    /// stated preference. Icons with no preference are never listed — silence
    /// is not a request.
    public var misplaced: [Misplaced] {
        items.compactMap { item in
            guard !item.isOurs, item.presence != .notDrawn,
                  let want = preferences.desired(for: item.preferenceKey)
            else { return nil }
            let isWhereItShouldBe = (want == .hidden && item.presence == .hidden)
                || (want == .visible && item.presence == .visible)
            return isWhereItShouldBe ? nil : Misplaced(item: item, desired: want)
        }
    }

    public var hidden: [Item] { items.filter { $0.presence == .hidden && !$0.isOurs } }

    /// Icons actually inside one of our groups.
    ///
    /// Distinct from `hidden`, which is every icon macOS is not currently
    /// drawing in a bar — including ones parked for reasons that have nothing
    /// to do with us. Counting those made the slime look stuffed while the
    /// groups were empty, claiming credit for other apps' business.
    public var held: [Item] {
        items.filter { !$0.isOurs && zone(of: $0)?.groupIndex != nil }
    }
    public var visible: [Item] { items.filter { $0.presence == .visible && !$0.isOurs } }
    /// Published but undrawn — surfaced in diagnostics, not in the icon list.
    public var notDrawn: [Item] { items.filter { $0.presence == .notDrawn && !$0.isOurs } }

    public func refresh() {
        isAuthorized = AXIsProcessTrusted()

        // Beacon for diagnosing permission problems from outside the app.
        //
        // A shell-run diagnostic answers for the *terminal host*, not for
        // ZipBar — TCC attributes the check to the responsible process, which
        // is how a contaminated measurement once claimed rebuilds were safe.
        // The only trustworthy report of what the GUI app sees is one the GUI
        // app writes itself.
        UserDefaults.standard.set(isAuthorized, forKey: "com.zipbar.beacon.axTrusted")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "com.zipbar.beacon.at")
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

            let key = IconPreferenceStore.key(
                bundleIdentifier: snapshot.bundleIdentifier,
                ownerName: snapshot.ownerName ?? "?",
                indexInApp: indexInApp
            )

            return Item(
                id: snapshot.id,
                ownerName: snapshot.ownerName ?? L("알 수 없는 앱"),
                bundleIdentifier: snapshot.bundleIdentifier,
                title: snapshot.title,
                frame: snapshot.frame,
                processIdentifier: pid,
                indexInApp: indexInApp,
                presence: Self.classify(snapshot.frame, bands: bands),
                isOurs: snapshot.bundleIdentifier == Bundle.main.bundleIdentifier,
                preferenceKey: key,
                position: Self.position(of: snapshot.frame, bands: bands),
                storedPosition: snapshot.bundleIdentifier.flatMap { bundle in
                    let keys = arranger.positionKeys(for: bundle)
                    let positionKey = keys.indices.contains(indexInApp)
                        ? keys[indexInApp] : keys.first
                    return positionKey.flatMap {
                        arranger.storedPosition(for: bundle, key: $0)
                    }
                }
            )
        }

        // Activity only means anything while an icon is out of sight.
        let hiddenIDs = Set(items.filter { $0.presence == .hidden }.map(\.id))
        activeIDs = stillActive.intersection(hiddenIDs)

        reconcile()
    }

    /// Squares the books between what was asked for and what the bar shows.
    ///
    /// Two updates, both in the direction of reality:
    ///
    /// - A pending move whose icon now sits on the requested side has taken
    ///   effect; its record is done and keeping it would show a "restart"
    ///   button for a move that already happened.
    /// - A stated preference that disagrees with reality *without* a pending
    ///   move can only come from the user ⌘-dragging the icon themselves.
    ///   Their drag is their decision; the preference follows it rather than
    ///   nagging them to undo what they just did on purpose.
    private func reconcile() {
        for item in items where item.presence != .notDrawn && !item.isOurs {
            let actual: IconPreferenceStore.Desired = item.presence == .hidden ? .hidden : .visible

            if let record = pendingStore.record(for: item.preferenceKey) {
                let wanted: IconPreferenceStore.Desired =
                    record.side == .hidden ? .hidden : .visible
                if wanted == actual {
                    pendingStore.remove(for: item.preferenceKey)
                }
            } else if let desired = preferences.desired(for: item.preferenceKey),
                      desired != actual {
                preferences.set(actual, for: item.preferenceKey)
            }
        }
    }

    /// Forget outstanding activity — called when the user opens the group and
    /// has therefore had the chance to see whatever changed.
    public func clearActivity() {
        activeIDs.removeAll()
    }

    /// Whether any hidden icon is flagged, which is what the slime shows.
    public var hasActivity: Bool { !activeIDs.isEmpty }

    // MARK: - Zones

    /// Boundaries as of the last refresh, leftmost first. Supplied by the
    /// owner rather than read here, because the engine is what knows which
    /// groups exist and where their separators are stored.
    @Published public var boundaries: [MenuBarEngine.Boundary] = []

    /// Indices of the groups that are shut right now, supplied by the owner
    /// because the engine is what tracks collapse state.
    @Published public var collapsedGroups: Set<Int> = []

    /// Icons the slime is concealing at this moment.
    ///
    /// Distinct from `held`, which is everything the groups own whether or not
    /// they are shut. An open group is holding nothing — it has let its icons
    /// out onto the bar — so a slime drawn from `held` stayed stuffed while
    /// the icons it was supposedly holding sat in plain sight beside it.
    public var concealed: [Item] {
        items.filter { item in
            guard !item.isOurs, let index = zone(of: item)?.groupIndex else { return false }
            return collapsedGroups.contains(index)
        }
    }

    /// Which zone an icon sits in, or nil when it cannot be placed.
    ///
    /// On-screen icons are read from where they actually are. Hidden ones
    /// cannot be: separators nest, so collapsing the outer group sweeps the
    /// inner group's icons past the inner boundary too, and every hidden icon
    /// piles into the leftmost zone regardless of which group holds it. For
    /// those the stored position answers instead — it is what the icon will
    /// return to, and it does not move when the icon is shoved off-screen.
    ///
    /// The stored value can lag a ⌘-drag until the owning app next saves, so
    /// it is only trusted where the live frame has nothing to say.
    public func zone(of item: Item) -> MenuBarZone? {
        let positions = boundaries.map(\.position)
        if item.presence == .visible {
            return MenuBarZoning.zone(for: item.position, boundaries: positions)
        }
        return MenuBarZoning.zone(for: item.storedPosition, boundaries: positions)
            ?? MenuBarZoning.zone(for: item.position, boundaries: positions)
    }

    /// Movable icons in one zone, left to right as they appear in the bar.
    public func items(in zone: MenuBarZone) -> [Item] {
        items
            .filter { !$0.isOurs && $0.presence != .notDrawn && self.zone(of: $0) == zone }
            .sorted { ($0.position ?? 0) > ($1.position ?? 0) }
    }

    /// Sends an icon to a zone by name — the group feature's one action.
    ///
    /// Same mechanism as `move(_:to:boundaryPosition:)`, aimed at an arbitrary
    /// zone instead of just the two sides of a single separator.
    @discardableResult
    public func move(_ item: Item, toZone zone: MenuBarZone) -> Bool {
        guard canMove(item),
              let bundle = item.bundleIdentifier,
              let target = MenuBarZoning.targetPosition(
                for: zone,
                boundaries: boundaries.map(\.position),
                clearance: MenuBarArranger.clearance)
        else { return false }

        let keys = arranger.positionKeys(for: bundle)
        let key = keys.indices.contains(item.indexInApp) ? keys[item.indexInApp]
            : (keys.first ?? "NSStatusItem Preferred Position Item-0")
        let plan = MenuBarArranger.Plan(
            bundleIdentifier: bundle, ownerName: item.ownerName, key: key,
            currentPosition: arranger.storedPosition(for: bundle, key: key),
            targetPosition: target,
            side: zone == .visible ? .visible : .hidden)

        guard case .some(let previous) = arranger.apply(plan) else { return false }

        pendingStore.set(
            PendingMoveStore.Record(
                bundleIdentifier: bundle, positionKey: key,
                previousValue: previous,
                targetValue: target,
                side: zone == .visible ? .visible : .hidden),
            for: item.preferenceKey)
        setDesired(zone == .visible ? .visible : .hidden, for: item)
        objectWillChange.send()
        return true
    }

    /// Swaps an icon with its neighbour inside the same zone.
    ///
    /// - Parameter towardLeft: true moves it further from the clock.
    ///
    /// Reordering is the same mechanism as moving between zones — write the
    /// stored position, wait for the app to restart — so it inherits the
    /// same caveat and the same pending record. macOS treats the position
    /// as a hint and packs items together, so the result is "next to that
    /// one", not a guaranteed pixel.
    @discardableResult
    public func reorder(_ item: Item, towardLeft: Bool) -> Bool {
        guard canMove(item), let zone = zone(of: item) else { return false }
        let siblings = items(in: zone)
        guard let index = siblings.firstIndex(where: { $0.id == item.id }) else { return false }

        // `items(in:)` is sorted left to right, so the neighbour to swap with
        // is the previous entry when moving left.
        let neighbourIndex = towardLeft ? index - 1 : index + 1
        guard siblings.indices.contains(neighbourIndex) else { return false }
        let neighbour = siblings[neighbourIndex]

        guard let mine = positionKeyAndValue(for: item),
              let theirs = positionKeyAndValue(for: neighbour) else { return false }

        // An app that publishes more items than it stores positions for maps
        // several of them onto the same key — Control Center does exactly
        // this. Swapping a key with itself writes nothing and would report
        // success, so the pair is refused instead.
        guard !(mine.bundle == theirs.bundle && mine.key == theirs.key) else { return false }

        // Swap the two stored positions outright rather than nudging by a
        // step: a nudge can land on top of a third icon, while a swap keeps
        // every other position untouched.
        return write(theirs.value, to: mine, side: zone == .visible ? .visible : .hidden)
            && write(mine.value, to: theirs, side: zone == .visible ? .visible : .hidden)
    }

    private struct PositionSlot {
        let item: Item
        let bundle: String
        let key: String
        let value: Double
    }

    private func positionKeyAndValue(for item: Item) -> PositionSlot? {
        guard let bundle = item.bundleIdentifier else { return nil }
        let keys = arranger.positionKeys(for: bundle)
        let key = keys.indices.contains(item.indexInApp) ? keys[item.indexInApp]
            : (keys.first ?? "NSStatusItem Preferred Position Item-0")
        // Fall back to where it actually is when the app has never stored a
        // position, so a first-time swap still has something to trade.
        let value = arranger.storedPosition(for: bundle, key: key) ?? item.position ?? 0
        return PositionSlot(item: item, bundle: bundle, key: key, value: value)
    }

    private func write(
        _ value: Double, to slot: PositionSlot, side: PendingMoveStore.Record.Side
    ) -> Bool {
        let plan = MenuBarArranger.Plan(
            bundleIdentifier: slot.bundle, ownerName: slot.item.ownerName, key: slot.key,
            currentPosition: slot.value, targetPosition: value,
            side: side == .hidden ? .hidden : .visible)
        guard case .some(let previous) = arranger.apply(plan) else { return false }
        pendingStore.set(
            PendingMoveStore.Record(
                bundleIdentifier: slot.bundle, positionKey: slot.key,
                previousValue: previous, targetValue: value, side: side),
            for: slot.item.preferenceKey)
        objectWillChange.send()
        return true
    }

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

    /// Converts an AX frame into a distance from the right edge of the screen
    /// it sits on.
    ///
    /// Separator positions come from macOS's own stored preferences, which use
    /// that measure; comparing raw x coordinates against them would be
    /// comparing two different origins, and on a three-display Mac the answer
    /// would be wrong on two of them.
    nonisolated static func position(of frame: CGRect?, bands: [CGRect]) -> Double? {
        guard let frame else { return nil }
        // Matched by vertical overlap alone, never by full intersection.
        // Hiding an icon *means* shoving it off the side of the display, so
        // requiring it to still overlap a bar horizontally refused to place
        // exactly the icons the group is holding — every collapsed group read
        // as empty. Pushed far left the x goes hugely negative, which turns
        // into a hugely positive distance from the right edge, and that is
        // precisely "deep inside the leftmost zone".
        guard let band = bands.first(where: {
            frame.minY < $0.maxY && frame.maxY > $0.minY
        }) else { return nil }
        return Double(band.maxX - frame.minX)
    }

    nonisolated static func classify(_ frame: CGRect?, bands: [CGRect]) -> Presence {
        guard let frame else { return .notDrawn }
        if frame.width <= 1 || frame.height <= 1 { return .notDrawn }
        return bands.contains { $0.intersects(frame) } ? .visible : .hidden
    }
}
