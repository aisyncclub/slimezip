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
            case .collapsible: return "접기/펴기"
            case .alwaysHidden: return "항상 숨김"
            }
        }
    }

    public var id: UUID
    public var name: String
    /// SF Symbol drawn in the chevron for this group.
    public var symbolName: String
    public var behavior: Behavior
    /// Collapse again once the pointer leaves the menu bar.
    public var autoHide: Bool
    /// Grace period before auto-hide fires.
    public var autoHideDelay: TimeInterval

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "chevron.left",
        behavior: Behavior = .collapsible,
        autoHide: Bool = true,
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
            MenuBarGroup(name: "숨김", symbolName: "chevron.left")
        ])
    }

    public func group(id: MenuBarGroup.ID) -> MenuBarGroup? {
        groups.first { $0.id == id }
    }
}
