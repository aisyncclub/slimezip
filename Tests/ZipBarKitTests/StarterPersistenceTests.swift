import Testing
import Foundation
@testable import ZipBarKit

/// Group IDs become `NSStatusItem.autosaveName`s, which is how macOS
/// remembers where the user ⌘-dragged each separator. If the starter layout
/// were regenerated per launch, every launch would mint new UUIDs and quietly
/// discard the arrangement the user just made.
@Suite("스타터 레이아웃 안정성")
struct StarterPersistenceTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() {
        suiteName = "com.zipbar.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    private func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("첫 실행 시 스타터가 즉시 저장된다")
    func starterIsWrittenOnFirstLoad() {
        defer { cleanUp() }
        #expect(defaults.data(forKey: ProfileStore.defaultsKey) == nil)

        _ = ProfileStore(defaults: defaults).load()

        #expect(defaults.data(forKey: ProfileStore.defaultsKey) != nil,
                "스타터 레이아웃이 디스크에 남아야 재실행 시 같은 ID를 쓴다")
    }

    @Test("재실행해도 그룹 ID가 유지된다")
    func groupIdentitiesSurviveRelaunch() {
        defer { cleanUp() }
        let firstLaunch = ProfileStore(defaults: defaults).load()
        // A brand new store, as if the app had quit and started again.
        let secondLaunch = ProfileStore(defaults: defaults).load()

        #expect(firstLaunch.groups.map(\.id) == secondLaunch.groups.map(\.id),
                "ID가 바뀌면 autosaveName이 바뀌어 구분자 위치를 잃는다")
    }

    @Test("손상된 설정을 복구한 뒤에도 ID가 안정적이다")
    func identitiesAreStableAfterSalvagingCorruptData() {
        defer { cleanUp() }
        defaults.set(Data("not json".utf8), forKey: ProfileStore.defaultsKey)

        let recovered = ProfileStore(defaults: defaults).load()
        let afterRelaunch = ProfileStore(defaults: defaults).load()

        #expect(recovered.groups.map(\.id) == afterRelaunch.groups.map(\.id))
    }
}
