import Testing
import Foundation
@testable import ZipBarKit

/// The arranger rewrites another app's stored icon position — the one move
/// mechanism that measurement showed works (AX writes are refused, synthetic
/// ⌘-drags ignored). Getting the arithmetic or the undo wrong here scatters
/// someone's menu bar, so both are pinned down.
@Suite("메뉴바 어레인저")
struct MenuBarArrangerTests {

    /// An isolated defaults suite standing in for another app's domain.
    private func sandbox(_ name: String) -> (MenuBarArranger, UserDefaults, String) {
        let suite = "com.zipbar.tests.arranger.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let arranger = MenuBarArranger(defaultsFor: { _ in UserDefaults(suiteName: suite) })
        return (arranger, defaults, suite)
    }

    // MARK: - Target arithmetic

    @Test("숨기기는 경계보다 왼쪽(큰 값)에 놓는다")
    func hiddenLandsLeftOfBoundary() {
        // Positions are distances from the right edge: larger is further left,
        // and further left is where the separator's inflation reaches.
        let target = MenuBarArranger.targetPosition(boundaryPosition: 800, side: .hidden)
        #expect(target > 800)
    }

    @Test("꺼내기는 경계보다 오른쪽(작은 값)에 놓는다")
    func visibleLandsRightOfBoundary() {
        let target = MenuBarArranger.targetPosition(boundaryPosition: 800, side: .visible)
        #expect(target < 800)
    }

    @Test("경계가 화면 오른쪽 끝에 붙어 있어도 음수가 되지 않는다")
    func visibleTargetNeverGoesNegative() {
        // A negative position is exactly the poisoned state StatusItemPlacement
        // exists to repair; the arranger must never create one.
        let target = MenuBarArranger.targetPosition(boundaryPosition: 10, side: .visible)
        #expect(target >= 0)
    }

    // MARK: - Plans

    @Test("저장된 키가 없으면 관례상의 첫 키로 계획한다")
    func plansWithConventionalKeyWhenNoneStored() throws {
        let (arranger, _, _) = sandbox(#function)
        let plan = try #require(arranger.plan(
            bundleIdentifier: "com.example.fresh", ownerName: "Fresh",
            indexInApp: 0, side: .hidden, boundaryPosition: 700))
        #expect(plan.key == "NSStatusItem Preferred Position Item-0")
        #expect(plan.currentPosition == nil)
    }

    @Test("번들 ID가 없으면 계획하지 않는다")
    func refusesWithoutBundleIdentifier() {
        let (arranger, _, _) = sandbox(#function)
        #expect(arranger.plan(
            bundleIdentifier: nil, ownerName: "Mystery",
            indexInApp: 0, side: .hidden, boundaryPosition: 700) == nil)
    }

    @Test("여러 아이템을 가진 앱은 인덱스로 키를 고른다")
    func picksKeyByIndex() throws {
        let (arranger, defaults, _) = sandbox(#function)
        defaults.set(100.0, forKey: "NSStatusItem Preferred Position Item-0")
        defaults.set(200.0, forKey: "NSStatusItem Preferred Position Item-1")

        let plan = try #require(arranger.plan(
            bundleIdentifier: "com.example.two", ownerName: "Two",
            indexInApp: 1, side: .hidden, boundaryPosition: 700))
        #expect(plan.key == "NSStatusItem Preferred Position Item-1")
        #expect(plan.currentPosition == 200.0)
    }

    // MARK: - Apply and revert

    @Test("적용은 이전 값을 돌려주고 새 값을 쓴다")
    func applyWritesAndReturnsPrevious() throws {
        let (arranger, defaults, _) = sandbox(#function)
        defaults.set(360.0, forKey: "NSStatusItem Preferred Position Item-0")

        let plan = try #require(arranger.plan(
            bundleIdentifier: "com.example.app", ownerName: "App",
            indexInApp: 0, side: .hidden, boundaryPosition: 800))
        let previous = try #require(arranger.apply(plan))

        #expect(previous == 360.0)
        #expect(defaults.object(forKey: plan.key) as? Double == plan.targetPosition)
    }

    @Test("되돌리기는 이전 값을 복원한다")
    func revertRestoresPreviousValue() throws {
        let (arranger, defaults, _) = sandbox(#function)
        defaults.set(360.0, forKey: "NSStatusItem Preferred Position Item-0")

        let plan = try #require(arranger.plan(
            bundleIdentifier: "com.example.app", ownerName: "App",
            indexInApp: 0, side: .hidden, boundaryPosition: 800))
        let previous = try #require(arranger.apply(plan))
        arranger.revert(plan, to: previous)

        #expect(defaults.object(forKey: plan.key) as? Double == 360.0)
    }

    @Test("원래 값이 없었으면 되돌리기가 키를 제거한다")
    func revertRemovesKeyWhenThereWasNone() throws {
        // Leaving a key we invented would hand the app a position it never
        // chose — a quieter version of the poisoning this project debugged.
        let (arranger, defaults, _) = sandbox(#function)
        let plan = try #require(arranger.plan(
            bundleIdentifier: "com.example.fresh", ownerName: "Fresh",
            indexInApp: 0, side: .hidden, boundaryPosition: 800))
        let previous = try #require(arranger.apply(plan))
        #expect(previous == nil)

        arranger.revert(plan, to: previous)
        #expect(defaults.object(forKey: plan.key) == nil)
    }
}
