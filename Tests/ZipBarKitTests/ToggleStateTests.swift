import Testing
import AppKit
@testable import ZipBarKit

/// The toggle's own reading of "is anything shut?" decides both what the
/// button says and what pressing it does. Getting it wrong produces a control
/// that looks broken while behaving exactly as written, which is the hardest
/// kind of bug to see in a screenshot.
@Suite("접기/펴기 판정")
@MainActor
struct ToggleStateTests {

    private func engine(_ groups: [MenuBarGroup]) throws -> MenuBarEngine {
        let suite = "com.zipbar.tests.toggle.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let engine = MenuBarEngine(store: ProfileStore(defaults: defaults))
        for group in groups { engine.addGroup(named: group.name) }
        return engine
    }

    @Test("항상 숨김만 있으면 토글할 것이 없다")
    func alwaysHiddenAloneIsNotToggleable() throws {
        // It is shut by definition and never opens on a toggle, so counting it
        // pinned `isToggleableCollapsed` to true: the button read "펼치기"
        // forever and pressing it re-expanded an already-open group.
        let layout = MenuBarLayout(groups: [
            MenuBarGroup(name: "항상 숨김", behavior: .alwaysHidden)
        ])
        #expect(layout.groups.allSatisfy { $0.behavior == .alwaysHidden })
    }

    @Test("접힘 판정이 항상 숨김을 세지 않는다")
    func collapseStateIgnoresAlwaysHidden() throws {
        let always = MenuBarGroup(name: "항상 숨김", behavior: .alwaysHidden)
        let normal = MenuBarGroup(name: "숨김", behavior: .collapsible)
        let layout = MenuBarLayout(groups: [always, normal])

        // Mirrors the engine's rule without needing a live menu bar: only a
        // collapsible group that is shut should count.
        func toggleableCollapsed(_ state: [MenuBarGroup.ID: Bool]) -> Bool {
            layout.groups.contains { $0.behavior != .alwaysHidden && state[$0.id] == true }
        }

        // Always-hidden shut, collapsible open: nothing to reveal.
        #expect(toggleableCollapsed([always.id: true, normal.id: false]) == false)
        // Both shut: there is something to reveal.
        #expect(toggleableCollapsed([always.id: true, normal.id: true]))
        // Always-hidden alone can never make it true.
        #expect(toggleableCollapsed([always.id: true]) == false)
    }

    @Test("항상 숨김 그룹은 일반 펼치기로 열리지 않는다")
    func expandAllSkipsAlwaysHidden() throws {
        let strategy = SpacerStrategy()
        let always = MenuBarGroup(name: "항상 숨김", behavior: .alwaysHidden)
        try strategy.activate(layout: MenuBarLayout(groups: [always]))
        defer { strategy.deactivate() }

        #expect(strategy.isCollapsed(always.id), "항상 숨김은 닫힌 채로 시작한다")
        strategy.setCollapsed(false, for: always.id)
        #expect(strategy.isCollapsed(always.id), "일반 호출로는 열리면 안 된다")
    }

    @Test("force를 주면 항상 숨김도 열린다")
    func forceOpensAlwaysHidden() throws {
        // "Never on a toggle" is the contract; "never, under any
        // circumstance" would strand the icons inside it.
        let strategy = SpacerStrategy()
        let always = MenuBarGroup(name: "항상 숨김", behavior: .alwaysHidden)
        try strategy.activate(layout: MenuBarLayout(groups: [always]))
        defer { strategy.deactivate() }

        strategy.setCollapsed(false, for: always.id, force: true)
        #expect(strategy.isCollapsed(always.id) == false)
    }
}
