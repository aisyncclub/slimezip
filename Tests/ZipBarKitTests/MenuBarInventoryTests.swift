import Testing
import Foundation
@testable import ZipBarKit

/// Hidden state is derived from geometry rather than from our own records:
/// the user can ⌘-drag icons without telling the app, and the spacer backend
/// hides things by pushing them off the display.
///
/// The coordinate space is the trap. AX reports Core Graphics coordinates —
/// origin at the top-left of the primary screen, y downward — while
/// `NSScreen.frame` is AppKit's, origin bottom-left and y upward. Treating
/// every screen's menu bar as sitting at y = 0 classified the whole bar as
/// hidden, because on this machine the active bar is at y = -1077.
@Suite("메뉴바 인벤토리 분류")
struct MenuBarInventoryTests {

    /// Single 1920×1080 display: its menu bar band is at y 0.
    private let single = [CGRect(x: 0, y: 0, width: 1920, height: 30)]

    /// The real Mac Studio arrangement, converted to CG space: the primary at
    /// y 0, and two screens stacked above it at y -1080.
    private let studio = [
        CGRect(x: 0, y: 0, width: 1920, height: 30),
        CGRect(x: 1015, y: -1080, width: 1920, height: 30),
        CGRect(x: -905, y: -1080, width: 1920, height: 30),
    ]

    @Test("바 안의 아이템은 보이는 것으로 분류된다")
    func onscreenIsVisible() {
        #expect(MenuBarInventory.classify(
            CGRect(x: 1400, y: 0, width: 24, height: 22), bands: single) == .visible)
    }

    @Test("주 화면 위에 쌓인 디스플레이의 아이템도 보이는 것으로 인정된다")
    func itemOnScreenAbovePrimaryIsVisible() {
        // Measured on the real machine: the active bar sits at y = -1077.
        #expect(MenuBarInventory.classify(
            CGRect(x: 2343, y: -1077, width: 24, height: 24), bands: studio) == .visible)
    }

    @Test("화면 밖으로 밀려난 아이템은 숨겨진 것으로 분류된다")
    func pushedOffIsHidden() {
        // What the spacer backend does when a group collapses.
        #expect(MenuBarInventory.classify(
            CGRect(x: -2799, y: 0, width: 40, height: 22), bands: single) == .hidden)
    }

    @Test("어느 밴드에도 걸치지 않는 좌표는 숨김이다")
    func parkedItemIsHidden() {
        // Measured: undrawn items get parked at the bottom of the primary.
        #expect(MenuBarInventory.classify(
            CGRect(x: -1, y: 1079, width: 34, height: 24), bands: studio) == .hidden)
    }

    @Test("크기가 0인 아이템은 숨김이 아니라 미표시로 분류된다")
    func zeroSizedIsNotDrawn() {
        // Control Center alone publishes a dozen of these; calling them
        // hidden would bury the icons that really are.
        #expect(MenuBarInventory.classify(
            CGRect(x: 0, y: 1080, width: 0, height: 0), bands: studio) == .notDrawn)
    }

    @Test("frame이 없으면 미표시로 분류된다")
    func missingFrameIsNotDrawn() {
        #expect(MenuBarInventory.classify(nil, bands: single) == .notDrawn)
    }

    @Test("메뉴바 아래 창은 숨김으로 분류된다")
    func belowTheBandIsHidden() {
        #expect(MenuBarInventory.classify(
            CGRect(x: 800, y: 400, width: 40, height: 22), bands: single) == .hidden)
    }

    @Test("디스플레이가 하나면 음수 x는 숨김이다")
    func negativeXHiddenOnSingleDisplay() {
        #expect(MenuBarInventory.classify(
            CGRect(x: -600, y: 0, width: 24, height: 22), bands: single) == .hidden)
    }
}
