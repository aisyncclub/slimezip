import Testing
import CoreGraphics
@testable import ZipBarKit

/// The hiding trick is pure arithmetic, and getting it wrong is invisible
/// until someone plugs in a second monitor. These pin the boundaries.
@Suite("스페이서 기하")
struct SpacerGeometryTests {

    @Test("숨김 길이는 가장 넓은 화면의 2배")
    func hidingLengthIsTwiceTheWidestScreen() {
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 1_440) == 2_880)
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 3_024) == 6_048)
    }

    @Test("숨김 길이는 하한 아래로 내려가지 않는다")
    func hidingLengthNeverDropsBelowTheFloor() {
        // A narrow or momentarily-zero screen width must still produce a
        // length large enough to push icons off, or hiding silently no-ops.
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 0) == 500)
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 100) == 500)
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 250) == 500)
        // Just past the floor it starts tracking the screen again.
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 260) == 520)
    }

    @Test("숨김 길이는 시스템 상한 10,000으로 클램프된다")
    func hidingLengthIsClampedToSystemMaximum() {
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 6_000) == 10_000)
        #expect(SpacerGeometry.hidingLength(widestScreenWidth: 100_000) == 10_000)
    }

    @Test("접힘 상태는 등호가 아니라 비교로 판정된다")
    func collapsedIsDerivedByComparisonNotEquality() {
        // The hiding length gets recomputed while collapsed (display added,
        // resolution changed). An equality check against a specific length
        // would lose the collapsed state; a threshold survives it.
        #expect(SpacerGeometry.isCollapsed(length: SpacerGeometry.expandedLength) == false)
        #expect(SpacerGeometry.isCollapsed(length: 2_880))
        #expect(SpacerGeometry.isCollapsed(length: 10_000))
        #expect(SpacerGeometry.isCollapsed(length: 500))
    }

    @Test("접힘 임계값은 배타적")
    func collapsedThresholdIsExclusive() {
        // Relative to the threshold rather than a literal: the threshold has
        // to move whenever the separator gains a new open width, and a test
        // pinned to the old number fails for the wrong reason.
        let threshold = SpacerGeometry.collapsedThreshold
        #expect(SpacerGeometry.isCollapsed(length: threshold) == false)
        #expect(SpacerGeometry.isCollapsed(length: threshold + 0.5))
    }

    @Test("메뉴바 밴드는 visibleFrame 위에서 화면 top까지")
    func menuBarBandSpansVisibleFrameTopToScreenTop() {
        let band = SpacerGeometry.menuBarBand(
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 875)
        )
        #expect(band.lowerBound == 875)
        #expect(band.upperBound == 900)
    }

    @Test("포인터가 메뉴바 안에 있는지 판정")
    func pointerInsideMenuBarBandIsDetected() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 875)

        #expect(SpacerGeometry.isPointInMenuBarBand(
            CGPoint(x: 700, y: 890), screenFrame: screen, visibleFrame: visible))
        // Below the band — pointer has left the menu bar, auto-hide may fire.
        #expect(SpacerGeometry.isPointInMenuBarBand(
            CGPoint(x: 700, y: 860), screenFrame: screen, visibleFrame: visible) == false)
        // Horizontally off this screen entirely.
        #expect(SpacerGeometry.isPointInMenuBarBand(
            CGPoint(x: 2_000, y: 890), screenFrame: screen, visibleFrame: visible) == false)
    }

    @Test("전체 화면에서 밴드가 뒤집히지 않는다")
    func menuBarBandHandlesFullScreenWhereVisibleFrameMeetsScreenTop() {
        // In full screen the menu bar is hidden and visibleFrame reaches the
        // top. The band must degenerate rather than invert, which would trap
        // on ClosedRange construction.
        let band = SpacerGeometry.menuBarBand(
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
        )
        #expect(band.lowerBound == 900)
        #expect(band.upperBound == 900)
    }
}
