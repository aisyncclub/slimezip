import Testing
import Foundation
@testable import ZipBarKit

/// ZipBar's own items are the only ones it can reposition without waiting
/// for an app to restart, because it is the app that creates them. The
/// arithmetic that decides where they land is worth pinning down: pushing
/// them past the edge of the display would hide the app's entire UI, which
/// is the failure `StatusItemPlacement.sanitize` exists to repair.
@Suite("자기 위치 이동")
struct SelfPlacementTests {

    private let width: Double = 1920

    @Test("모든 아이템이 같은 양만큼 움직인다")
    func shiftPreservesSpacing() {
        // Spacing is the invariant: the slime has to stay a fixed distance
        // right of the boundary it inflates, or icons can settle between
        // them and "left of the slime" stops meaning "hidden".
        let before = [802.0, 762.0, 722.0]
        let after = SelfPlacement.shifted(positions: before, by: 34, widestScreenWidth: width)
        #expect(after == [836, 796, 756])
        for (a, b) in zip(before, after) { #expect(b - a == 34) }
    }

    @Test("음수 델타는 오른쪽으로 옮긴다")
    func negativeDeltaMovesRight() {
        let after = SelfPlacement.shifted(positions: [400, 360], by: -34, widestScreenWidth: width)
        #expect(after == [366, 326])
    }

    @Test("화면 밖으로 밀려나지 않는다")
    func clampedAtTheLeftEdge() {
        // Past the widest display an item is unreachable — exactly the state
        // the placement repair exists to undo, so the mover must not create it.
        let limit = SelfPlacement.maximum(widestScreenWidth: width)
        let after = SelfPlacement.shifted(
            positions: [limit - 5, limit - 45], by: 500, widestScreenWidth: width)
        #expect(after.max()! <= limit + 0.001)
        // Even while clamped the gap survives.
        #expect(after[0] - after[1] == 40)
    }

    @Test("오른쪽 끝을 넘어 음수가 되지 않는다")
    func clampedAtTheRightEdge() {
        let after = SelfPlacement.shifted(positions: [40, 0], by: -500, widestScreenWidth: width)
        #expect(after.min()! >= -0.001)
        #expect(after[0] - after[1] == 40)
    }

    @Test("더 갈 곳이 없으면 이동 불가로 보고한다")
    func reportsWhenPinned() {
        // Drives the disabled state of the buttons: a control that looks
        // available and does nothing is worse than one plainly switched off.
        let limit = SelfPlacement.maximum(widestScreenWidth: width)
        #expect(SelfPlacement.canShift(
            positions: [limit], by: 34, widestScreenWidth: width) == false)
        #expect(SelfPlacement.canShift(
            positions: [0], by: -34, widestScreenWidth: width) == false)
        #expect(SelfPlacement.canShift(
            positions: [400], by: 34, widestScreenWidth: width))
    }

    @Test("빈 목록은 그대로 돌려준다")
    func emptyIsUntouched() {
        #expect(SelfPlacement.shifted(positions: [], by: 34, widestScreenWidth: width).isEmpty)
    }

    @Test("한 걸음이 눈에 띌 만큼은 된다")
    func stepIsVisible() {
        // Roughly one status item wide. Smaller and a click reads as a
        // broken button rather than a move.
        #expect(SelfPlacement.step >= 20)
        #expect(SelfPlacement.step <= 60)
    }
}
