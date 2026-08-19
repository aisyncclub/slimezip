import Testing
import AppKit
@testable import ZipBarKit

/// Regression guard for a bug that made the app look completely broken.
///
/// `NSImage(systemSymbolName:)` returns nil for a name that does not exist,
/// and a status item with a nil image and an empty title draws nothing at
/// all. `line.3.vertical` is not a real SF Symbol, so ZipBar's separator was
/// invisible in the menu bar and the app appeared not to have launched.
///
/// Symbol availability also varies by macOS release, so this suite is not
/// just about the one typo — it fails on the machine where a glyph went away.
@Suite("SF Symbol 가용성")
struct SymbolAvailabilityTests {

    @Test("구분자 심볼이 존재한다")
    func separatorSymbolResolves() {
        #expect(StatusItemGlyph.resolves(SpacerStrategy.separatorSymbol),
                "'\(SpacerStrategy.separatorSymbol)'가 이 macOS에 없습니다 — 구분자가 보이지 않게 됩니다")
    }

    @Test("펼침 셰브론 심볼이 존재한다")
    func expandedSymbolResolves() {
        #expect(StatusItemGlyph.resolves(MenuBarGroup.expandedSymbol))
    }

    @Test("설정에서 고를 수 있는 모든 셰브론이 존재한다", arguments: MenuBarGroup.symbolChoices)
    func everyOfferedSymbolResolves(symbol: String) {
        #expect(StatusItemGlyph.resolves(symbol), "'\(symbol)'가 이 macOS에 없습니다")
    }

    @Test("기본 그룹의 심볼이 존재한다")
    func defaultGroupSymbolResolves() {
        for group in MenuBarLayout.starter.groups {
            #expect(StatusItemGlyph.resolves(group.symbolName))
        }
    }

    @Test("없는 심볼은 텍스트로 대체된다")
    @MainActor
    func missingSymbolFallsBackToText() {
        let item = NSStatusBar.system.statusItem(withLength: 20)
        defer { NSStatusBar.system.removeStatusItem(item) }

        StatusItemGlyph.apply(
            to: item.button,
            symbolName: "definitely.not.a.real.symbol",
            fallbackText: "|",
            accessibilityDescription: "테스트"
        )

        #expect(item.button?.image == nil)
        #expect(item.button?.title == "|", "심볼이 없어도 항목은 보여야 한다")
    }

    @Test("있는 심볼은 이미지를 쓰고 텍스트를 비운다")
    @MainActor
    func presentSymbolUsesImage() {
        let item = NSStatusBar.system.statusItem(withLength: 20)
        defer { NSStatusBar.system.removeStatusItem(item) }

        StatusItemGlyph.apply(
            to: item.button,
            symbolName: "chevron.left",
            fallbackText: "|",
            accessibilityDescription: "테스트"
        )

        #expect(item.button?.image != nil)
        #expect(item.button?.title == "")
    }
}
