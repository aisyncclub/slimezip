import Testing
@testable import ZipBarKit

/// The slime's width is a reading of how many icons it is holding, so the
/// mapping from count to stage is behaviour, not decoration.
@Suite("슬라임 단계")
struct SlimeRendererTests {

    @Test("비어 있으면 가장 홀쭉한 단계")
    func emptyIsThinnest() {
        // An empty slime that already looked plump would have nothing left to
        // say once it filled up.
        #expect(SlimeRenderer.stage(forHiddenCount: 0) == 1)
    }

    @Test("하나만 숨겨도 홀쭉함을 벗어난다")
    func oneHiddenLeavesTheThinnestStage() {
        #expect(SlimeRenderer.stage(forHiddenCount: 1) > 1)
    }

    @Test("꽉 차면 가장 뚱뚱한 단계")
    func fullIsFattest() {
        #expect(SlimeRenderer.stage(forHiddenCount: SlimeRenderer.fullAt) == SlimeRenderer.stageCount)
    }

    @Test("포화 이후에도 단계를 넘지 않는다")
    func staysWithinRangeWhenOverfull() {
        for count in [SlimeRenderer.fullAt + 1, 40, 500] {
            #expect(SlimeRenderer.stage(forHiddenCount: count) == SlimeRenderer.stageCount)
        }
    }

    @Test("개수가 늘면 단계가 줄지 않는다", arguments: 0..<20)
    func stageNeverShrinksAsCountGrows(count: Int) {
        #expect(SlimeRenderer.stage(forHiddenCount: count)
                <= SlimeRenderer.stage(forHiddenCount: count + 1))
    }

    @Test("모든 단계가 유효 범위 안에 있다", arguments: 0..<30)
    func stageAlwaysInRange(count: Int) {
        let stage = SlimeRenderer.stage(forHiddenCount: count)
        #expect(stage >= 1 && stage <= SlimeRenderer.stageCount)
    }
}
