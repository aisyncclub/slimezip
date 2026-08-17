import Testing
import Foundation
@testable import ZipBarKit

/// Each test gets its own defaults suite, so persistence tests never collide
/// with each other or with the developer's real ZipBar settings.
@Suite("레이아웃 영속화")
struct LayoutPersistenceTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() {
        suiteName = "com.zipbar.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    private func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("레이아웃 인코딩/디코딩 왕복")
    func layoutSurvivesRoundTrip() throws {
        defer { cleanUp() }
        let original = MenuBarLayout(groups: [
            MenuBarGroup(name: "작업", symbolName: "bolt.horizontal", behavior: .collapsible,
                         autoHide: true, autoHideDelay: 7),
            MenuBarGroup(name: "보관", symbolName: "archivebox", behavior: .alwaysHidden,
                         autoHide: false, autoHideDelay: 3),
        ])

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(MenuBarLayout.self, from: data)

        #expect(restored == original)
        #expect(restored.groups.map(\.id) == original.groups.map(\.id))
    }

    @Test("저장소 왕복")
    func storeRoundTripsThroughDefaults() {
        defer { cleanUp() }
        let store = ProfileStore(defaults: defaults)
        let layout = MenuBarLayout(groups: [MenuBarGroup(name: "테스트")])

        store.save(layout)
        #expect(store.load() == layout)
    }

    @Test("첫 실행에는 스타터 레이아웃")
    func firstLaunchGetsStarterLayout() {
        defer { cleanUp() }
        let loaded = ProfileStore(defaults: defaults).load()
        #expect(loaded.groups.count == 1)
        #expect(loaded.version == MenuBarLayout.currentVersion)
    }

    @Test("읽을 수 없는 설정은 버리지 않고 보존한다")
    func unreadableLayoutIsSalvagedRatherThanDiscarded() {
        defer { cleanUp() }
        // A config we cannot decode is a config we would otherwise overwrite
        // on the next save, losing the user's setup with no trace.
        let garbage = Data("not json".utf8)
        defaults.set(garbage, forKey: ProfileStore.defaultsKey)

        let loaded = ProfileStore(defaults: defaults).load()

        #expect(loaded.groups.count == 1, "손상된 설정은 기본값으로 대체된다")
        #expect(defaults.data(forKey: ProfileStore.defaultsKey + ".unreadable") == garbage,
                "원본은 복구를 위해 보존된다")
    }

    @Test("그룹 이동이 SwiftUI onMove 의미와 일치한다")
    @MainActor
    func moveGroupsMatchesSwiftUIOnMoveSemantics() {
        defer { cleanUp() }
        let store = ProfileStore(defaults: defaults)
        store.save(MenuBarLayout(groups: [
            MenuBarGroup(name: "A"), MenuBarGroup(name: "B"),
            MenuBarGroup(name: "C"), MenuBarGroup(name: "D"),
        ]))
        let engine = MenuBarEngine(store: store)

        // Dragging the first row down to index 3 lands it between B and C,
        // which is what SwiftUI's List does.
        engine.moveGroups(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(engine.layout.groups.map(\.name) == ["B", "C", "A", "D"])

        // Dragging the last row to the top.
        engine.moveGroups(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(engine.layout.groups.map(\.name) == ["D", "B", "C", "A"])
    }

    @Test("그룹 편집이 즉시 저장된다")
    @MainActor
    func groupEditsPersistImmediately() throws {
        defer { cleanUp() }
        let store = ProfileStore(defaults: defaults)
        let engine = MenuBarEngine(store: store)

        engine.addGroup(named: "새 그룹")
        var group = try #require(engine.layout.groups.last)
        group.name = "이름 변경"
        engine.update(group)

        #expect(ProfileStore(defaults: defaults).load().groups.last?.name == "이름 변경")

        engine.removeGroup(id: group.id)
        #expect(!ProfileStore(defaults: defaults).load().groups.contains { $0.id == group.id })
    }
}
