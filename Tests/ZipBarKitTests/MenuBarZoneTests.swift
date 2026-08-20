import Testing
import Foundation
@testable import ZipBarKit

/// Zones are what make groups mean anything: without them the app can only
/// say "hidden" or "visible" and every group collapses into the same bucket.
///
/// Positions are distances from the right edge of the screen, so **larger is
/// further left**. That inversion is the easiest thing to get backwards here,
/// so the fixtures spell out the arrangement they describe.
@Suite("메뉴바 구역")
struct MenuBarZoneTests {

    /// Two groups, arranged the usual way:
    ///
    ///     [ 항상 숨김 ] │800│ [ 숨김 ] │700│ [ 보임 ] 🟢
    private let twoGroups: [Double] = [800, 700]

    // MARK: - Placing an icon

    @Test("가장 왼쪽 구분자보다 왼쪽이면 첫 그룹")
    func leftOfEverythingIsFirstGroup() {
        #expect(MenuBarZoning.zone(for: 900, boundaries: twoGroups) == .group(0))
    }

    @Test("두 구분자 사이면 두 번째 그룹")
    func betweenBoundariesIsSecondGroup() {
        #expect(MenuBarZoning.zone(for: 750, boundaries: twoGroups) == .group(1))
    }

    @Test("모든 구분자보다 오른쪽이면 보임")
    func rightOfEverythingIsVisible() {
        #expect(MenuBarZoning.zone(for: 600, boundaries: twoGroups) == .visible)
    }

    @Test("그룹이 하나면 구분자 왼쪽이 그 그룹")
    func singleGroupSplitsInTwo() {
        #expect(MenuBarZoning.zone(for: 850, boundaries: [800]) == .group(0))
        #expect(MenuBarZoning.zone(for: 750, boundaries: [800]) == .visible)
    }

    @Test("그리지 않는 아이콘은 배치할 수 없다")
    func undrawnIconHasNoZone() {
        // Control Centre publishes a dozen zero-sized items; claiming they are
        // "visible" would put them in the list as movable icons.
        #expect(MenuBarZoning.zone(for: nil, boundaries: twoGroups) == nil)
    }

    @Test("구분자가 없으면 전부 보임")
    func noBoundariesMeansVisible() {
        #expect(MenuBarZoning.zone(for: 500, boundaries: []) == .visible)
    }

    // MARK: - Aiming a move

    @Test("목표 위치는 요청한 구역 안에 떨어진다", arguments: [
        MenuBarZone.group(0), .group(1), .visible,
    ])
    func targetLandsInsideItsOwnZone(zone: MenuBarZone) {
        // The round trip is the real contract: aim at a zone, and reading the
        // result back has to give that same zone.
        let target = MenuBarZoning.targetPosition(
            for: zone, boundaries: twoGroups, clearance: 40)
        let landed = MenuBarZoning.zone(for: target, boundaries: twoGroups)
        #expect(landed == zone, "\(zone)를 겨냥했는데 \(String(describing: landed))에 떨어졌다")
    }

    @Test("가운데 구역은 두 구분자의 중간을 겨냥한다")
    func middleZoneAimsForItsCentre() {
        // macOS treats the position as a hint and packs items together, so a
        // target sitting on the boundary can settle either side of it.
        let target = MenuBarZoning.targetPosition(
            for: .group(1), boundaries: twoGroups, clearance: 40)
        #expect(target == 750)
    }

    @Test("보임 목표가 화면 밖으로 나가지 않는다")
    func visibleTargetStaysOnScreen() {
        // A boundary parked near the right edge must not produce a negative
        // position, which would place the icon off the display entirely.
        let target = MenuBarZoning.targetPosition(
            for: .visible, boundaries: [10], clearance: 40)
        #expect(target == 0)
    }

    @Test("없는 그룹을 겨냥하면 목표가 없다")
    func unknownGroupHasNoTarget() {
        #expect(MenuBarZoning.targetPosition(
            for: .group(5), boundaries: twoGroups, clearance: 40) == nil)
    }

    @Test("구분자가 없으면 목표도 없다")
    func noBoundariesHasNoTarget() {
        #expect(MenuBarZoning.targetPosition(
            for: .group(0), boundaries: [], clearance: 40) == nil)
    }
}
