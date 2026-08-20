import Testing
import Foundation
@testable import ZipBarKit

/// The motion curves are what make the slime read as alive rather than as a
/// glyph being rescaled, so their shape is worth pinning down.
@Suite("슬라임 모션")
struct SlimeAnimatorTests {

    private let motions: [SlimeAnimator.Motion] = [.breathe, .jiggle, .twitch]

    @Test("모든 모션은 정지 상태에서 시작한다")
    func startsAtRest() {
        for motion in motions {
            #expect(motion.squash(at: 0) == 0, "\(motion)이 튀며 시작한다")
        }
    }

    @Test("모든 모션은 정지 상태로 끝난다")
    func settlesBackToRest() {
        // A motion that ended mid-deformation would leave the slime stuck
        // squashed until something else moved it.
        for motion in motions {
            #expect(abs(motion.squash(at: 1)) < 0.005, "\(motion)이 찌그러진 채 끝난다")
        }
    }

    @Test("변형이 정규화 범위를 넘지 않는다")
    func staysWithinNormalisedRange() {
        // Curves are normalised −1...1 and the renderer scales them to the
        // canvas. A curve overshooting would be silently clamped, so the
        // motion would flatten at its peak instead of ringing.
        for motion in motions {
            for step in 0...100 {
                let value = abs(motion.squash(at: Double(step) / 100))
                #expect(value <= 1.0 + 0.0001,
                        "\(motion)이 \(step)%에서 범위를 넘는다: \(value)")
            }
        }
    }

    @Test("늘어남이 캔버스 여유 안에 들어간다")
    func stretchFitsTheCanvas() {
        // The canvas is padded by maxSquash in both directions while the
        // drawing sits maxStretch above the floor, so a full stretch must not
        // exceed what is left — otherwise the dome is clipped flat, which is
        // the opposite of stretching.
        let tallest = (1 + SlimeRenderer.maxStretch) + SlimeRenderer.maxStretch
        #expect(tallest <= 1 + SlimeRenderer.maxSquash + 0.0001)
    }

    @Test("젤리는 늘어나기보다 눌리는 쪽이 크다")
    func squashesFurtherThanItStretches() {
        #expect(SlimeRenderer.maxSquash > SlimeRenderer.maxStretch)
    }

    @Test("반응 모션이 숨쉬기보다 크고 짧다")
    func reactionsAreSharperThanIdle() {
        func peak(_ motion: SlimeAnimator.Motion) -> CGFloat {
            (0...100).map { abs(motion.squash(at: Double($0) / 100)) }.max() ?? 0
        }
        // A reaction that was gentler than breathing would not read as a
        // response to the click that caused it.
        #expect(peak(.jiggle) > peak(.breathe))
        #expect(SlimeAnimator.Motion.jiggle.duration < SlimeAnimator.Motion.breathe.duration)
    }

    @Test("출렁임은 여러 번 흔들리고 잦아든다")
    func jiggleOscillatesAndDecays() {
        let samples = (0...100).map { SlimeAnimator.Motion.jiggle.squash(at: Double($0) / 100) }
        let crossings = zip(samples, samples.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
        #expect(crossings >= 3, "한 번만 눌렸다 펴지면 젤리로 보이지 않는다")

        let firstHalf = samples.prefix(50).map(abs).max() ?? 0
        let secondHalf = samples.suffix(50).map(abs).max() ?? 0
        #expect(secondHalf < firstHalf, "진폭이 잦아들어야 한다")
    }

    @Test("숨과 깜빡임 간격이 기계적으로 일정하지 않다")
    func idleGapsAreRanges() {
        // Both are randomised: a fixed interval reads as a machine ticking
        // rather than as something alive. The lower bounds are only there to
        // stop the idle loop turning into continuous animation, which would
        // cost CPU for the whole session.
        #expect(SlimeAnimator.breathGap.lowerBound < SlimeAnimator.breathGap.upperBound)
        #expect(SlimeAnimator.breathGap.lowerBound >= 1.5)
        #expect(SlimeAnimator.blinkGap.lowerBound < SlimeAnimator.blinkGap.upperBound)
        #expect(SlimeAnimator.blinkGap.lowerBound >= 1.5)
    }

    @Test("깜빡임은 눈에 띄지 않을 만큼 짧다")
    func blinkIsBrief() {
        // Roughly a human blink. Longer and the slime looks asleep.
        #expect(SlimeAnimator.blinkDuration > 0.05)
        #expect(SlimeAnimator.blinkDuration < 0.3)
    }
}

/// The status item must not resize while the slime moves.
@Suite("슬라임 캔버스 안정성")
struct SlimeCanvasTests {

    @Test("정지와 변형의 캔버스 크기가 같다")
    @MainActor
    func canvasSizeIsConstant() throws {
        guard let rest = SlimeRenderer.image(hiddenCount: 3, hasActivity: false, squash: 0) else {
            // Artwork is not bundled during unit tests; nothing to compare.
            return
        }
        for squash in [-SlimeRenderer.maxSquash, -0.05, 0.05, SlimeRenderer.maxSquash] {
            let moved = try #require(
                SlimeRenderer.image(hiddenCount: 3, hasActivity: false, squash: squash))
            #expect(moved.size == rest.size,
                    "squash \(squash)에서 크기가 달라지면 이웃 아이콘이 밀린다")
        }
    }
}

/// Curves that are never delivered animate nothing, so the timer machinery
/// gets its own coverage: the app's CPU cost while idle is indistinguishable
/// from the animation silently not running.
@Suite("슬라임 애니메이터 구동")
struct SlimeAnimatorDriveTests {

    /// Spins the main run loop, which is what Timer needs to fire.
    @MainActor
    private func pump(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    @Test("모션이 프레임을 실제로 전달한다")
    @MainActor
    func deliversFrames() {
        let animator = SlimeAnimator()
        var frames: [CGFloat] = []
        animator.onFrame = { squash, _ in frames.append(squash) }

        animator.play(.jiggle)
        pump(for: SlimeAnimator.Motion.jiggle.duration + 0.3)

        #expect(frames.count > 8, "프레임이 \(frames.count)개뿐 — 타이머가 돌지 않았다")
        #expect(frames.contains { abs($0) > 0.3 }, "변형이 눈에 띄는 크기까지 가지 않았다")
        #expect(abs(frames.last ?? 1) < 0.01, "마지막 프레임이 정지 상태가 아니다")
    }

    @Test("멈추면 정지 상태로 되돌린다")
    @MainActor
    func stopSettlesToRest() {
        let animator = SlimeAnimator()
        var last: CGFloat = 99
        animator.onFrame = { squash, _ in last = squash }

        animator.play(.breathe)
        pump(for: 0.3)
        animator.stop()

        #expect(last == 0, "멈춘 뒤 찌그러진 채 남으면 안 된다")
    }

    @Test("쉬는 동안에는 프레임을 내보내지 않는다")
    @MainActor
    func silentWhileResting() {
        // The whole reason the animation is intermittent: a menu bar app runs
        // for the entire session, so it must cost nothing between motions.
        let animator = SlimeAnimator()
        animator.play(.twitch)
        pump(for: SlimeAnimator.Motion.twitch.duration + 0.2)

        var framesAfterSettling = 0
        animator.onFrame = { _, _ in framesAfterSettling += 1 }
        pump(for: 0.5)

        #expect(framesAfterSettling == 0, "쉬는 중에 \(framesAfterSettling)프레임이 나갔다")
    }
}
