import Testing
@testable import ZipBarKit

/// The glyph is a count you read at a glance, so how many slimes get drawn —
/// and what happens once the row hits its width cap — is behaviour.
@Suite("슬라임 개수와 단계")
struct SlimeRendererTests {

    @Test("숨긴 것이 없어도 한 마리는 그린다")
    func emptyStillDrawsOne() {
        // An empty bar should show a slime waiting to be fed, not a blank
        // space the user cannot find or click.
        #expect(SlimeRenderer.slimeCount(forHiddenCount: 0) == 1)
        #expect(SlimeRenderer.stage(forHiddenCount: 0) == 1)
    }

    @Test("상한까지는 개수가 그대로 늘어난다", arguments: 1...SlimeRenderer.maxVisibleSlimes)
    func countTracksHiddenIconsUpToTheCap(hidden: Int) {
        #expect(SlimeRenderer.slimeCount(forHiddenCount: hidden) == hidden)
    }

    @Test("상한을 넘으면 줄이 더 길어지지 않는다", arguments: [5, 9, 40, 500])
    func rowStopsGrowingPastTheCap(hidden: Int) {
        // An app that exists to reclaim menu bar space must not eat it one
        // slime at a time.
        #expect(SlimeRenderer.slimeCount(forHiddenCount: hidden) == SlimeRenderer.maxVisibleSlimes)
    }

    @Test("상한을 넘으면 대신 통통해진다")
    func fullnessTakesOverPastTheCap() {
        let atCap = SlimeRenderer.stage(forHiddenCount: SlimeRenderer.maxVisibleSlimes)
        let over = SlimeRenderer.stage(forHiddenCount: SlimeRenderer.fullAt)
        #expect(over > atCap, "개수가 멈췄으면 다른 신호가 이어받아야 한다")
        #expect(over == SlimeRenderer.stageCount)
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

    @Test("눈 감은 그림이 뜬 그림과 같은 크기다")
    @MainActor
    func blinkMatchesOpenSize() {
        // A blink that resizes the slime reads as a twitch, and at the row's
        // scale it would shove every slime beside it.
        for stage in 1...SlimeRenderer.stageCount {
            guard let open = SlimeRenderer.stageImage(stage, blinking: false),
                  let blink = SlimeRenderer.stageImage(stage, blinking: true)
            else { return }   // artwork is not bundled during unit tests
            #expect(open.size == blink.size, "\(stage)단계에서 크기가 다르다")
        }
    }
}
