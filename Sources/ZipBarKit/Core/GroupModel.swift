import Foundation

/// A named, collapsible section of the menu bar.
///
/// Bartender and Ice both hard-code exactly two sections ("hidden" and
/// "always hidden"). ZipBar lets the user define as many as they want, each
/// with its own chevron — that is the differentiator, and it is achievable
/// even with the permission-free spacer backend.
public struct MenuBarGroup: Identifiable, Codable, Hashable, Sendable {
    public enum Behavior: String, Codable, Sendable, CaseIterable {
        /// Chevron toggles the group open and shut.
        case collapsible
        /// Stays shut unless explicitly opened; never auto-expands.
        case alwaysHidden

        public var displayName: String {
            switch self {
            case .collapsible: return L("접기/펴기")
            case .alwaysHidden: return L("항상 숨김")
            }
        }
    }

    public var id: UUID
    public var name: String
    /// SF Symbol drawn in the chevron for this group.
    public var symbolName: String
    public var behavior: Behavior
    /// Collapse again once the pointer leaves the menu bar.
    ///
    /// Off by default. With it on, the group shut itself a few seconds after
    /// launch and swallowed whatever happened to sit left of the slime — on
    /// this machine that was LM Studio and both Claude icons, none of which
    /// the user had chosen to hide. Hiding icons the user never picked is
    /// worse than leaving the bar untidy, so the first collapse is theirs to
    /// make; auto-hide is worth turning on only once the group holds what
    /// they want it to hold.
    public var autoHide: Bool
    /// Grace period before auto-hide fires.
    public var autoHideDelay: TimeInterval

    /// Retained only so existing saved profiles still decode.
    ///
    /// The chevron these named is gone: the slime is now the only item ZipBar
    /// puts in the bar, and it draws its own artwork. Nothing renders
    /// `symbolName` any more, so offering a picker for it asked the user to
    /// choose something they would never see.
    public static let symbolChoices = [
        "chevron.left", "chevron.left.2", "ellipsis.circle",
        "square.stack.3d.up", "tray.full", "archivebox", "bolt.horizontal",
    ]

    /// Unused since the chevron was removed; kept for profile compatibility.
    public static let expandedSymbol = "chevron.right"

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "chevron.left",
        behavior: Behavior = .collapsible,
        autoHide: Bool = false,
        autoHideDelay: TimeInterval = 3
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.behavior = behavior
        self.autoHide = autoHide
        self.autoHideDelay = autoHideDelay
    }
}

/// The user's full menu bar configuration.
///
/// Groups are ordered left-to-right as they appear in the bar. Because the
/// spacer backend cannot move other apps' icons, this ordering describes
/// where our *separators* sit; the user drags their icons between them.
public struct MenuBarLayout: Codable, Hashable, Sendable {
    public var groups: [MenuBarGroup]
    /// Schema version, so a future format change can migrate rather than
    /// silently discard someone's setup.
    public var version: Int

    public static let currentVersion = 1

    public init(groups: [MenuBarGroup] = [], version: Int = MenuBarLayout.currentVersion) {
        self.groups = groups
        self.version = version
    }

    /// What a first-run user gets: one ordinary collapsible group.
    public static var starter: MenuBarLayout {
        MenuBarLayout(groups: [
            MenuBarGroup(name: L("숨김"), symbolName: "chevron.left")
        ])
    }

    public func group(id: MenuBarGroup.ID) -> MenuBarGroup? {
        groups.first { $0.id == id }
    }
}
