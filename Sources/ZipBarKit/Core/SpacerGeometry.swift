import CoreGraphics
import Foundation

/// Pure geometry for the length-inflation hiding trick, kept free of AppKit
/// so it can be unit tested without a menu bar.
///
/// The mechanism: a status item whose length is inflated to roughly twice the
/// widest attached screen shoves every icon to its left off the display. See
/// `docs/RESEARCH.md` for provenance.
public enum SpacerGeometry {
    /// macOS refuses status item lengths beyond this.
    public static let maxStatusItemLength: CGFloat = 10_000

    /// Never inflate to less than this, or the trick fails on small displays
    /// while an external monitor is asleep.
    public static let minimumHidingLength: CGFloat = 500

    /// Width of the separator when the group is open.
    public static let expandedLength: CGFloat = 20

    /// A separator longer than this is considered collapsed.
    ///
    /// Deliberately a comparison and not an equality check: the hiding length
    /// gets recomputed while collapsed (display added, resolution changed) and
    /// the collapsed state has to survive that.
    public static let collapsedThreshold: CGFloat = 20

    /// Length that pushes everything to the separator's left off screen.
    public static func hidingLength(widestScreenWidth: CGFloat) -> CGFloat {
        max(minimumHidingLength, min(widestScreenWidth * 2, maxStatusItemLength))
    }

    /// Collapse state is derived from the live length, never stored, so it
    /// cannot drift out of sync with what the menu bar is actually doing.
    public static func isCollapsed(length: CGFloat) -> Bool {
        length > collapsedThreshold
    }

    /// The strip of screen occupied by the menu bar: everything above the
    /// visible frame and below the top of the screen.
    ///
    /// Used to decide whether the pointer is still "in" the menu bar, which
    /// re-arms the auto-hide timer instead of collapsing under the cursor.
    public static func menuBarBand(screenFrame: CGRect, visibleFrame: CGRect) -> ClosedRange<CGFloat> {
        let lower = min(visibleFrame.maxY, screenFrame.maxY)
        return lower...screenFrame.maxY
    }

    public static func isPointInMenuBarBand(
        _ point: CGPoint,
        screenFrame: CGRect,
        visibleFrame: CGRect
    ) -> Bool {
        guard point.x >= screenFrame.minX, point.x <= screenFrame.maxX else { return false }
        return menuBarBand(screenFrame: screenFrame, visibleFrame: visibleFrame).contains(point.y)
    }
}
