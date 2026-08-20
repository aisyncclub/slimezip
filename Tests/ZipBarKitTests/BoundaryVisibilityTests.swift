import Testing
import AppKit
@testable import ZipBarKit

/// The separator is invisible in normal use so the slime is ZipBar's only
/// icon. That breaks down while the user is arranging: they cannot aim a drag
/// at a line they cannot see, and other apps' icons can land between the
/// boundary and the slime, which makes "left of the slime" simply wrong.
@Suite("경계 표시")
@MainActor
struct BoundaryVisibilityTests {

    private func activated() throws -> (SpacerStrategy, MenuBarGroup.ID) {
        let strategy = SpacerStrategy()
        let layout = MenuBarLayout.starter
        let id = try #require(layout.groups.first?.id)
        try strategy.activate(layout: layout)
        return (strategy, id)
    }

    @Test("평소에는 경계가 보이지 않는다")
    func hiddenByDefault() throws {
        let (strategy, id) = try activated()
        defer { strategy.deactivate() }
        #expect(strategy.separatorLength(for: id) == SpacerGeometry.expandedLength)
    }

    @Test("배치 중에는 경계가 넓어진다")
    func widensWhileArranging() throws {
        let (strategy, id) = try activated()
        defer { strategy.deactivate() }

        strategy.setBoundaryVisible(true)
        let shown = try #require(strategy.separatorLength(for: id))
        #expect(shown == SpacerStrategy.boundaryLength)
        #expect(shown > SpacerGeometry.expandedLength, "겨냥할 수 없을 만큼 좁으면 의미가 없다")
    }

    @Test("배치가 끝나면 다시 사라진다")
    func collapsesBackAfterwards() throws {
        let (strategy, id) = try activated()
        defer { strategy.deactivate() }

        strategy.setBoundaryVisible(true)
        strategy.setBoundaryVisible(false)
        #expect(strategy.separatorLength(for: id) == SpacerGeometry.expandedLength)
    }

    @Test("접혀 있는 동안에는 경계 표시가 팽창을 건드리지 않는다")
    func doesNotDisturbACollapsedGroup() throws {
        let (strategy, id) = try activated()
        defer { strategy.deactivate() }

        strategy.setCollapsed(true, for: id)
        let inflated = try #require(strategy.separatorLength(for: id))

        // Shrinking the separator here would un-hide everything it is holding.
        strategy.setBoundaryVisible(true)
        #expect(strategy.separatorLength(for: id) == inflated)
        #expect(strategy.isCollapsed(id))
    }

    @Test("배치 중에 펼치면 좁은 폭이 아니라 경계 폭으로 돌아온다")
    func expandingWhileArrangingKeepsTheBoundary() throws {
        let (strategy, id) = try activated()
        defer { strategy.deactivate() }

        strategy.setBoundaryVisible(true)
        strategy.setCollapsed(true, for: id)
        strategy.setCollapsed(false, for: id)

        #expect(strategy.separatorLength(for: id) == SpacerStrategy.boundaryLength,
                "펼치면서 경계가 사라지면 배치를 이어갈 수 없다")
    }
}

/// The collapse test reads the separator's live width, so every width the
/// separator legitimately takes has to fall on the right side of it.
@Suite("접힘 판정 임계값")
struct CollapseThresholdTests {

    @Test("열린 상태의 모든 폭이 접힘으로 오인되지 않는다")
    func openWidthsAreNotCollapsed() {
        // The boundary shown while arranging sat above the old threshold, so
        // turning it off left the separator stuck at its wide size.
        #expect(!SpacerGeometry.isCollapsed(length: SpacerGeometry.expandedLength))
        #expect(!SpacerGeometry.isCollapsed(length: SpacerStrategy.boundaryLength))
    }

    @Test("실제 숨김 폭은 언제나 접힘으로 판정된다", arguments: [800.0, 1920.0, 3840.0, 10_000.0])
    func hidingWidthsAreCollapsed(width: Double) {
        #expect(SpacerGeometry.isCollapsed(length: CGFloat(width)))
    }

    @Test("임계값이 보이는 폭과 숨김 폭 사이에 있다")
    func thresholdSitsBetweenTheTwoRegimes() {
        #expect(SpacerGeometry.collapsedThreshold > SpacerStrategy.boundaryLength)
        #expect(SpacerGeometry.collapsedThreshold < SpacerGeometry.minimumHidingLength)
    }
}
