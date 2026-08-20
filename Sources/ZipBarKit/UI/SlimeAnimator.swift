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

    /// Handed a fresh frame to display.
    public var onFrame: ((CGFloat) -> Void)?

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
    static let breathGap: ClosedRange<TimeInterval> = 4...9

    private var frameTimer: Timer?
    private var idleTimer: Timer?
    private var startedAt: Date?
    private var motion: Motion?
    private var idleBreathing = false

    public init() {}

    deinit {
        frameTimer?.invalidate()
        idleTimer?.invalidate()
    }

    /// Begins the idle rhythm. Safe to call repeatedly.
    public func startIdling() {
        guard !idleBreathing else { return }
        idleBreathing = true
        scheduleNextBreath()
    }

    public func stop() {
        idleBreathing = false
        idleTimer?.invalidate(); idleTimer = nil
        frameTimer?.invalidate(); frameTimer = nil
        motion = nil
        onFrame?(0)
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
            onFrame?(0)                 // settle back to the resting shape
            scheduleNextBreath()
            return
        }
        onFrame?(motion.squash(at: t))
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
