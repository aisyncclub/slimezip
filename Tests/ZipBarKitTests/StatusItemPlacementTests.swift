import Testing
import Foundation
@testable import ZipBarKit

/// Regression guard for the failure that hid ZipBar's entire UI.
///
/// Collapsing a group inflated the separator past the edge of the display and
/// pushed our own chevron and control item off-screen. macOS persisted those
/// displaced coordinates, so every later launch restored them off-screen too —
/// the app appeared not to be running, and relaunching could never fix it
/// because the bad state lived on disk.
@Suite("상태 아이템 배치")
struct StatusItemPlacementTests {

    private func defaults(_ name: String) -> UserDefaults {
        let suite = "com.zipbar.tests.\(name)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private func position(_ d: UserDefaults, _ name: String) -> Double? {
        d.object(forKey: StatusItemPlacement.key(for: name)) as? Double
    }

    // MARK: - sanitize

    @Test("화면 밖 위치는 폐기된다")
    func discardsOffscreenPosition() {
        let d = defaults(#function)
        d.set(4658.0, forKey: StatusItemPlacement.key(for: "chevron"))

        let repaired = StatusItemPlacement.sanitize(
            autosaveNames: ["chevron"], widestScreenWidth: 1920, defaults: d)

        #expect(repaired == ["chevron"])
        #expect(position(d, "chevron") == nil, "오염된 값은 남아 있으면 안 된다")
    }

    @Test("화면 안 위치는 보존된다")
    func keepsOnscreenPosition() {
        let d = defaults(#function)
        d.set(802.0, forKey: StatusItemPlacement.key(for: "separator"))

        let repaired = StatusItemPlacement.sanitize(
            autosaveNames: ["separator"], widestScreenWidth: 1920, defaults: d)

        #expect(repaired.isEmpty)
        #expect(position(d, "separator") == 802.0, "사용자가 드래그한 위치는 건드리지 않는다")
    }

    @Test("음수 위치도 폐기된다")
    func discardsNegativePosition() {
        let d = defaults(#function)
        d.set(-12.0, forKey: StatusItemPlacement.key(for: "control"))

        #expect(StatusItemPlacement.sanitize(
            autosaveNames: ["control"], widestScreenWidth: 1920, defaults: d) == ["control"])
    }

    @Test("저장값이 없으면 아무것도 하지 않는다")
    func absentPositionIsNotAnError() {
        let d = defaults(#function)
        #expect(StatusItemPlacement.sanitize(
            autosaveNames: ["missing"], widestScreenWidth: 1920, defaults: d).isEmpty)
    }

    // MARK: - enforceOrder

    @Test("셰브론과 제어는 구분자 오른쪽에 놓인다")
    func placesOurItemsRightOfSeparator() {
        let d = defaults(#function)
        let names = ["separator", "chevron", "control"]

        StatusItemPlacement.enforceOrder(leftToRight: names, widestScreenWidth: 1920, defaults: d)

        let p = names.map { position(d, $0)! }
        // Larger distance from the right edge means further left.
        #expect(p[0] > p[1], "구분자가 셰브론보다 왼쪽")
        #expect(p[1] > p[2], "셰브론이 제어보다 왼쪽")
    }

    @Test("순서가 뒤집혀 있으면 바로잡는다")
    func repairsInvertedOrder() {
        let d = defaults(#function)
        // The arrangement that caused the bug: our items left of the separator.
        d.set(100.0, forKey: StatusItemPlacement.key(for: "separator"))
        d.set(500.0, forKey: StatusItemPlacement.key(for: "chevron"))
        d.set(600.0, forKey: StatusItemPlacement.key(for: "control"))

        let moved = StatusItemPlacement.enforceOrder(
            leftToRight: ["separator", "chevron", "control"], widestScreenWidth: 1920, defaults: d)

        #expect(!moved.isEmpty)
        #expect(position(d, "separator")! > position(d, "chevron")!)
        #expect(position(d, "chevron")! > position(d, "control")!)
    }

    @Test("이미 올바른 순서는 건드리지 않는다")
    func leavesCorrectOrderAlone() {
        let d = defaults(#function)
        d.set(300.0, forKey: StatusItemPlacement.key(for: "separator"))
        d.set(200.0, forKey: StatusItemPlacement.key(for: "chevron"))
        d.set(100.0, forKey: StatusItemPlacement.key(for: "control"))

        let moved = StatusItemPlacement.enforceOrder(
            leftToRight: ["separator", "chevron", "control"], widestScreenWidth: 1920, defaults: d)

        #expect(moved.isEmpty, "사용자 배치를 보존해야 한다")
        #expect(position(d, "separator") == 300.0)
    }

    @Test("정리 후 순서 적용이 화면 안에 놓는다")
    func sanitizeThenOrderLandsOnscreen() {
        let d = defaults(#function)
        // Exactly the poisoned profile found on the real machine.
        d.set(802.0, forKey: StatusItemPlacement.key(for: "separator"))
        d.set(4658.0, forKey: StatusItemPlacement.key(for: "chevron"))
        d.set(4684.0, forKey: StatusItemPlacement.key(for: "control"))

        let names = ["separator", "chevron", "control"]
        StatusItemPlacement.sanitize(autosaveNames: names, widestScreenWidth: 1920, defaults: d)
        StatusItemPlacement.enforceOrder(leftToRight: names, widestScreenWidth: 1920, defaults: d)

        for name in names {
            let p = position(d, name)!
            #expect(p >= 0 && p <= 1920, "\(name)가 화면 밖에 있다: \(p)")
        }
    }
}
