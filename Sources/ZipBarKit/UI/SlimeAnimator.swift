import AppKit

/// Gives the slime a pulse.
///
/// Deliberately intermittent. A menu bar app runs for the whole session, so a
/// glyph redrawn thirty times a second would burn CPU for as long as the user
/// is logged in — and constant motion in the corner of the eye is tiring to
/// sit next to. Living things rest, so this one breathes now and then, reacts
/// when something happens to it, and otherwise holds still at zero cost.
@MainActor
public final class SlimeAnimator {

    /// Handed a fresh frame: how far to deform, and whether the eyes are shut.
    ///
    /// Blinking rides alongside the motion rather than being one of the
    /// motions, because eyes and body are independent — a slime can blink
    /// mid-breath, and making them share a track would force one to wait for
    /// the other and read as a stutter.
    public var onFrame: ((CGFloat, Bool) -> Void)?

    /// Motion the slime can perform.
    public enum Motion {
        /// A slow idle breath.
        case breathe
        /// A springy wobble for swallowing or releasing icons.
        case jiggle
        /// A small startle when a hidden icon changes.
        case twitch

        public var duration: TimeInterval {
            switch self {
            case .breathe: return 1.9
            case .jiggle: return 0.75
            case .twitch: return 0.45
            }
        }

        /// Deformation over normalised time, 0 through 1.
        ///
        /// Returns a normalised −1 through 1; the renderer scales it by its
        /// own squash and stretch limits, so curves here describe shape and
        /// timing without needing to know how far the canvas can give.
        public func squash(at t: Double) -> CGFloat {
            switch self {
            case .breathe:
                // One unhurried in-and-out.
                return CGFloat(sin(t * 2 * .pi)) * 0.62
            case .jiggle:
                // Squashes hard, then rings down like jelly settling.
                let decay = pow(1 - t, 1.7)
                return CGFloat(sin(t * 2 * .pi * 2.6) * decay)
            case .twitch:
                let decay = pow(1 - t, 2.0)
                return CGFloat(sin(t * 2 * .pi * 3.4) * decay) * 0.5
            }
        }
    }

    /// Frames per second while a motion is playing. Fast enough to read as
    /// motion, slow enough to stay cheap; nothing runs between motions.
    static let frameRate: TimeInterval = 24

    /// Range between idle breaths. Randomised so the rhythm never reads as a
    /// machine ticking.
    static let breathGap: ClosedRange<TimeInterval> = 2...5

    /// Range between blinks, and how long the eyes stay shut.
    ///
    /// Roughly a human resting rate. Regular enough to read as alive, varied
    /// enough that it never becomes a metronome in the corner of the eye.
    static let blinkGap: ClosedRange<TimeInterval> = 2.5...6.5
    static let blinkDuration: TimeInterval = 0.14
    /// Chance a blink comes in a pair, the way real ones often do.
    static let doubleBlinkChance = 0.25

    private var frameTimer: Timer?
    private var idleTimer: Timer?
    private var blinkTimer: Timer?
    private var isBlinking = false
    private var startedAt: Date?
    private var motion: Motion?
    private var idleBreathing = false

    public init() {}

    deinit {
        frameTimer?.invalidate()
        idleTimer?.invalidate()
        blinkTimer?.invalidate()
    }

    /// Begins the idle rhythm. Safe to call repeatedly.
    public func startIdling() {
        guard !idleBreathing else { return }
        idleBreathing = true
        scheduleNextBreath()
        scheduleNextBlink()
    }

    public func stop() {
        idleBreathing = false
        idleTimer?.invalidate(); idleTimer = nil
        blinkTimer?.invalidate(); blinkTimer = nil
        frameTimer?.invalidate(); frameTimer = nil
        motion = nil
        isBlinking = false
        onFrame?(0, false)
    }

    // MARK: - Blinking

    private func scheduleNextBlink() {
        guard idleBreathing else { return }
        blinkTimer?.invalidate()
        blinkTimer = schedule(after: .random(in: Self.blinkGap)) { [weak self] in
            self?.blink(remaining: Double.random(in: 0...1) < Self.doubleBlinkChance ? 1 : 0)
        }
    }

    private func blink(remaining: Int) {
        isBlinking = true
        emit()
        blinkTimer = schedule(after: Self.blinkDuration) { [weak self] in
            guard let self else { return }
            self.isBlinking = false
            self.emit()
            if remaining > 0 {
                // The gap inside a double blink, not a whole new interval.
                self.blinkTimer = self.schedule(after: 0.12) { [weak self] in
                    self?.blink(remaining: remaining - 1)
                }
            } else {
                self.scheduleNextBlink()
            }
        }
    }

    /// Timers on the common run loop mode, so nothing freezes while a menu is
    /// open — a slime that stops living the moment you click it is worse than
    /// one that never moved.
    private func schedule(after delay: TimeInterval, _ body: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in
            MainActor.assumeIsolated { body() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func emit() {
        onFrame?(currentSquash, isBlinking)
    }

    private var currentSquash: CGFloat {
        guard let motion, let startedAt else { return 0 }
        let t = Date().timeIntervalSince(startedAt) / motion.duration
        return t < 1 ? motion.squash(at: t) : 0
    }

    /// Plays a motion now, interrupting any idle breath.
    ///
    /// Reactions matter more than the idle loop: a wobble that arrives late
    /// because the slime was mid-breath would not read as a response to the
    /// click that caused it.
    public func play(_ motion: Motion) {
        frameTimer?.invalidate()
        self.motion = motion
        startedAt = Date()

        let timer = Timer(timeInterval: 1 / Self.frameRate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Common mode so the slime keeps moving while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func tick() {
        guard let motion, let startedAt else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        let t = elapsed / motion.duration

        guard t < 1 else {
            frameTimer?.invalidate(); frameTimer = nil
            self.motion = nil
            emit()                      // settle back to the resting shape
            scheduleNextBreath()
            return
        }
        onFrame?(motion.squash(at: t), isBlinking)
    }

    private func scheduleNextBreath() {
        guard idleBreathing else { return }
        idleTimer?.invalidate()
        let delay = TimeInterval.random(in: Self.breathGap)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.play(.breathe) }
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }
}
