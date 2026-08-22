import Testing
import Foundation
@testable import ZipBarKit

/// A move waits — sometimes hours — between the click and the restart that
/// makes it real. These pin down the bookkeeping for that gap: it must
/// survive relaunches, undo must restore exactly what was overwritten, and
/// the wait list must empty itself when reality catches up.
@Suite("대기 중인 이동")
struct PendingMoveTests {

    private func store(_ name: String) -> PendingMoveStore {
        let suite = "com.zipbar.tests.pending.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return PendingMoveStore(defaults: defaults)
    }

    private func record(
        side: PendingMoveStore.Record.Side = .hidden,
        previous: Double? = 360,
        target: Double = 641
    ) -> PendingMoveStore.Record {
        PendingMoveStore.Record(
            bundleIdentifier: "com.example.app",
            positionKey: "NSStatusItem Preferred Position Item-0",
            previousValue: previous,
            targetValue: target,
            side: side)
    }

    @Test("기록이 저장되고 읽힌다")
    func roundTrips() {
        let store = store(#function)
        store.set(record(), for: "com.example.app#0")
        #expect(store.record(for: "com.example.app#0") == record())
    }

    @Test("이전 값이 없었다는 사실도 보존된다")
    func preservesAbsentPrevious() {
        // "There was no value" must come back as nil, not as zero — undo
        // restores it by *removing* the key, and a zero would instead park
        // the icon at the screen's right edge.
        let store = store(#function)
        store.set(record(previous: nil), for: "a#0")
        let loaded = store.record(for: "a#0")
        #expect(loaded != nil)
        #expect(loaded?.previousValue == nil)
    }

    @Test("겹쳐 쓴 이동도 최초의 원본 값을 기억한다")
    func firstWriteWinsForUndo() {
        // Hide, then change your mind to visible before restarting: undo must
        // restore what the app originally had, not our own first rewrite.
        let store = store(#function)
        store.set(record(side: .hidden, previous: 360, target: 641), for: "a#0")
        store.set(record(side: .visible, previous: 762, target: 561), for: "a#0")

        let merged = store.record(for: "a#0")
        #expect(merged?.side == .visible, "방향은 최신 결정을 따른다")
        #expect(merged?.targetValue == 561, "목표는 최신 결정을 따른다")
        #expect(merged?.previousValue == 360, "되돌릴 값은 최초 원본이어야 한다")
    }

    @Test("목표 위치가 보존된다")
    func keepsTargetForReapplication() {
        // The write has to happen twice — once on request, once after the
        // owning app quits, because some apps save their live position on the
        // way out and overwrite ours. Losing the target loses the second write.
        let store = store(#function)
        store.set(record(target: 681), for: "a#0")
        #expect(store.record(for: "a#0")?.targetValue == 681)
    }

    @Test("제거하면 사라진다")
    func removeDeletes() {
        let store = store(#function)
        store.set(record(), for: "a#0")
        store.remove(for: "a#0")
        #expect(store.record(for: "a#0") == nil)
        #expect(store.all().isEmpty)
    }
}
