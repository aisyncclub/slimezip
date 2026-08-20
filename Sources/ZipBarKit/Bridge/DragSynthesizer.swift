import AppKit
import CoreGraphics

/// Synthesises the ⌘-drag that macOS requires for rearranging menu bar icons.
///
/// Accessibility reports every status item's position as read-only, so the
/// app cannot move an icon by setting an attribute. The remaining question is
/// whether it can perform the same gesture the user would: hold Command and
/// drag. Posting to `cghidEventTap` puts the events where a real device's
/// would arrive, which is what the menu bar's own drag handling watches.
///
/// AX gives frames in Core Graphics coordinates, the same space these events
/// use, so no conversion is needed between reading a position and dragging to
/// one.
public enum DragSynthesizer {

    /// Steps the pointer takes between the two points.
    ///
    /// The menu bar starts a drag from movement, not from the mouse-down
    /// alone, so a single jump to the destination can be discarded as a
    /// click. Intermediate moves also give the bar time to reflow.
    static let steps = 24

    /// Pause between posted events. Long enough for the menu bar to keep up,
    /// short enough that the whole gesture stays under a second.
    static let stepDelay: UInt32 = 12_000  // microseconds

    /// Drags from one point to another with Command held.
    ///
    /// - Returns: false when the event source cannot be created, which is
    ///   what happens without Accessibility permission.
    @discardableResult
    public static func commandDrag(from source: CGPoint, to target: CGPoint) -> Bool {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else { return false }

        // Suppress the local user's input from interleaving with ours mid
        // gesture, which would otherwise drop the icon somewhere unintended.
        eventSource.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalKeyboardEvents], state: .eventSuppressionStateSuppressionInterval)

        let flags: CGEventFlags = .maskCommand

        // Hold Command as a real key, not just as a flag on the mouse events.
        // The menu bar tracks modifier state itself, and a mouse event that
        // merely claims the flag is not the same thing as the key being down.
        setCommandKey(eventSource, down: true)
        usleep(stepDelay)

        post(eventSource, .mouseMoved, source, flags)
        usleep(stepDelay)
        post(eventSource, .leftMouseDown, source, flags)
        // Let the bar register the press before movement starts.
        usleep(stepDelay * 8)

        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: source.x + (target.x - source.x) * t,
                y: source.y + (target.y - source.y) * t
            )
            post(eventSource, .leftMouseDragged, point, flags)
            usleep(stepDelay)
        }

        usleep(stepDelay * 4)
        post(eventSource, .leftMouseUp, target, flags)
        usleep(stepDelay)
        setCommandKey(eventSource, down: false)
        return true
    }

    /// Virtual key code for the left Command key.
    private static let commandKey: CGKeyCode = 0x37

    private static func setCommandKey(_ source: CGEventSource, down: Bool) {
        guard let event = CGEvent(
            keyboardEventSource: source, virtualKey: commandKey, keyDown: down
        ) else { return }
        event.flags = down ? .maskCommand : []
        event.post(tap: .cghidEventTap)
    }

    private static func post(
        _ source: CGEventSource, _ type: CGEventType, _ point: CGPoint, _ flags: CGEventFlags
    ) {
        guard let event = CGEvent(
            mouseEventSource: source, mouseType: type,
            mouseCursorPosition: point, mouseButton: .left
        ) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}
