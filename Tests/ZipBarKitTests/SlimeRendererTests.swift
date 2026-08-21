import Testing
@testable import ZipBarKit

/// The glyph carries the count through how crushed the slimes look, in a slot
/// that never widens. Which drawing gets picked is therefore behaviour, and
/// the fixed footprint is a promise: an app that exists to reclaim menu bar
/// space must not spend it as it fills up.
@Suite("슬라임 단계")
struct SlimeRendererTests {

    @Test("숨긴 것이 없어도 한 마리는 그린다")
    func emptyStillDrawsOne() {
        // An empty bar should show a slime waiting to be fed, not a blank the
        // user cannot find or click.
        #expect(SlimeRenderer.stage(forHiddenCount: 0) == 1)
    }

    @Test("개수가 그대로 단계가 된다", arguments: 1...SlimeRenderer.stageCount)
    func stageTracksHiddenIcons(hidden: Int) {
        #expect(SlimeRenderer.stage(forHiddenCount: hidden) == hidden)
    }

    @Test("가득 찬 뒤에는 더 변하지 않는다", arguments: [6, 9, 40, 500])
    func stagePinsOnceFull(hidden: Int) {
        // Past a full slot the picture cannot say any more — the slimes are
        // already flat against every wall — so it stops pretending to
        // distinguish nine from ninety.
        #expect(SlimeRenderer.stage(forHiddenCount: hidden) == SlimeRenderer.stageCount)
    }

    @Test("단계가 줄어들지 않는다", arguments: 0..<20)
    func stageNeverShrinksAsCountGrows(count: Int) {
        #expect(SlimeRenderer.stage(forHiddenCount: count)
                <= SlimeRenderer.stage(forHiddenCount: count + 1))
    }

    @Test("모든 단계가 유효 범위 안에 있다", arguments: 0..<30)
    func stageAlwaysInRange(count: Int) {
        let stage = SlimeRenderer.stage(forHiddenCount: count)
        #expect(stage >= 1 && stage <= SlimeRenderer.stageCount)
    }

    @Test("어떤 개수에서도 글리프 폭이 같다")
    @MainActor
    func glyphFootprintNeverGrows() {
        // The whole reason the slimes squish instead of lining up: an earlier
        // version laid them in a row and reached 80pt at eight hidden icons,
        // wider than most of the icons it was hiding.
        guard let first = SlimeRenderer.image(hiddenCount: 0, hasActivity: false)
        else { return }   // artwork is not bundled during unit tests
        for count in [1, 3, 5, 8, 40] {
            guard let image = SlimeRenderer.image(hiddenCount: count, hasActivity: false)
            else { return }
            #expect(image.size == first.size, "\(count)개에서 폭이 달라졌다")
        }
    }

    @Test("눈 감은 그림이 뜬 그림과 같은 크기다")
    @MainActor
    func blinkMatchesOpenSize() {
        // A blink that resizes the glyph reads as a twitch and shoves every
        // neighbouring icon sideways.
        for stage in 1...SlimeRenderer.stageCount {
            guard let open = SlimeRenderer.stageImage(stage, blinking: false),
                  let blink = SlimeRenderer.stageImage(stage, blinking: true)
            else { return }
            #expect(open.size == blink.size, "\(stage)단계에서 크기가 다르다")
        }
    }

    @Test("깜빡임 그림이 없어도 글리프가 사라지지 않는다")
    @MainActor
    func missingBlinkFallsBackToOpenEyes() {
        // Returning nil here would drop the caller onto its symbol fallback
        // for the length of a blink, flickering the character out several
        // times a minute.
        guard SlimeRenderer.image(hiddenCount: 2, hasActivity: false) != nil
        else { return }
        #expect(SlimeRenderer.image(hiddenCount: 2, hasActivity: false, blinking: true) != nil)
    }
}
