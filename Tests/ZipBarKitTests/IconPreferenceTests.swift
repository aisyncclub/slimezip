import Testing
import Foundation
@testable import ZipBarKit

/// Preferences are the only way the app can be useful about placement: it
/// cannot move an icon, so its whole contribution is knowing which ones are
/// in the wrong place and saying so.
@Suite("아이콘 선호도")
struct IconPreferenceTests {

    private func store(_ name: String) -> (IconPreferenceStore, UserDefaults) {
        let suite = "com.zipbar.tests.prefs.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (IconPreferenceStore(defaults: defaults), defaults)
    }

    @Test("설정한 선호도가 저장된다")
    func storesAPreference() {
        let (store, _) = self.store(#function)
        store.set(.hidden, for: "com.example.app#0")
        #expect(store.desired(for: "com.example.app#0") == .hidden)
    }

    @Test("선호도 없음과 보이기 선호는 구분된다")
    func absentIsNotTheSameAsVisible() {
        // An icon the user has not ruled on must never show up as work to do.
        let (store, _) = self.store(#function)
        #expect(store.desired(for: "com.example.app#0") == nil)

        store.set(.visible, for: "com.example.app#0")
        #expect(store.desired(for: "com.example.app#0") == .visible)

        store.set(nil, for: "com.example.app#0")
        #expect(store.desired(for: "com.example.app#0") == nil, "지우면 무설정으로 돌아가야 한다")
    }

    @Test("한 앱의 여러 아이템이 따로 기억된다")
    func itemsWithinAnAppAreDistinct() {
        // Claude publishes two status items; a preference on one must not
        // silently apply to the other.
        let (store, _) = self.store(#function)
        let first = IconPreferenceStore.key(
            bundleIdentifier: "com.anthropic.claudefordesktop", ownerName: "Claude", indexInApp: 0)
        let second = IconPreferenceStore.key(
            bundleIdentifier: "com.anthropic.claudefordesktop", ownerName: "Claude", indexInApp: 1)
        #expect(first != second)

        store.set(.hidden, for: first)
        #expect(store.desired(for: second) == nil)
    }

    @Test("번들 ID가 없으면 앱 이름으로 대체한다")
    func fallsBackToOwnerName() {
        let key = IconPreferenceStore.key(
            bundleIdentifier: nil, ownerName: "SomeAgent", indexInApp: 0)
        #expect(key.contains("SomeAgent"))
        #expect(key != IconPreferenceStore.key(
            bundleIdentifier: nil, ownerName: "OtherAgent", indexInApp: 0))
    }

    @Test("키는 프로세스 ID를 담지 않는다")
    func keyIsStableAcrossRelaunch() {
        // The AX item id embeds a pid and changes whenever the owning app
        // restarts, which would silently discard every stored preference.
        let key = IconPreferenceStore.key(
            bundleIdentifier: "io.tailscale.ipn.macsys", ownerName: "Tailscale", indexInApp: 0)
        #expect(!key.contains("ax:"))
        #expect(key == IconPreferenceStore.key(
            bundleIdentifier: "io.tailscale.ipn.macsys", ownerName: "Tailscale", indexInApp: 0))
    }

    @Test("전체 삭제가 동작한다")
    func clearRemovesEverything() {
        let (store, _) = self.store(#function)
        store.set(.hidden, for: "a#0")
        store.set(.visible, for: "b#0")
        store.clear()
        #expect(store.all().isEmpty)
    }
}
