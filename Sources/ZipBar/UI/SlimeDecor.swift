import SwiftUI
import AppKit
import ZipBarKit

/// Slime artwork for the settings window.
///
/// The same drawings the menu bar uses, at sizes where their faces actually
/// read. In the bar a slime is 18pt and mostly silhouette; here there is room
/// for it to be the character it is, which is the point of having one.
enum SlimeDecor {

    /// A slime at a given fullness, or nil if the artwork is missing.
    static func image(stage: Int, blinking: Bool = false) -> Image? {
        SlimeRenderer.stageImage(stage, blinking: blinking).map { Image(nsImage: $0) }
    }

    /// Slime sized for a section header or an empty state.
    struct Portrait: View {
        var stage: Int
        var height: CGFloat = 26
        /// Blinks on its own so a static window still feels inhabited.
        var animated = true

        @State private var blinking = false

        var body: some View {
            Group {
                if let image = SlimeDecor.image(stage: stage, blinking: blinking && animated) {
                    image.resizable().scaledToFit()
                } else {
                    // Artwork missing: say nothing rather than draw a
                    // stand-in that would misreport how full the group is.
                    Color.clear
                }
            }
            .frame(height: height)
            .task(id: animated) {
                guard animated else { return }
                // Irregular on purpose — a fixed interval reads as a blinking
                // cursor rather than as something alive.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(.random(in: 2.5...6)))
                    guard !Task.isCancelled else { return }
                    blinking = true
                    try? await Task.sleep(for: .milliseconds(140))
                    blinking = false
                }
            }
        }
    }
}

/// A zone's heading: a slime whose fullness reflects what the zone holds,
/// beside the name and count.
struct ZoneHeader: View {
    let title: String
    let subtitle: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            SlimeDecor.Portrait(stage: Self.stage(for: count), height: 22)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(title) (\(count))")
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// Mirrors the menu bar's mapping so the two never disagree about how
    /// full a group looks.
    static func stage(for count: Int) -> Int {
        SlimeRenderer.stage(forHiddenCount: count)
    }
}
