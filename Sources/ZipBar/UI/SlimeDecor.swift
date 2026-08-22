import SwiftUI
import AppKit
import ZipBarKit

/// Slime artwork for the settings window.
///
/// The same drawings the menu bar uses, at sizes where their faces actually
/// read. In the bar a slime is 22pt tall and mostly silhouette; here there is
/// room for it to be the character it is, which is the point of having one.
///
/// Everything sizes from the artwork's own aspect ratio. The drawings are
/// wider than they are tall — a five-slime cluster more so — and pinning them
/// into a square frame squashed the very deformation the picture exists to
/// show.
enum SlimeDecor {

    /// Aspect ratio of the drawings, measured from the artwork rather than
    /// assumed, so re-cut artwork cannot silently distort.
    @MainActor
    static var aspectRatio: CGFloat {
        guard let image = SlimeRenderer.stageImage(1, blinking: false),
              image.size.height > 0
        else { return 1 }
        return image.size.width / image.size.height
    }

    static func image(stage: Int, blinking: Bool = false) -> Image? {
        SlimeRenderer.stageImage(stage, blinking: blinking).map { Image(nsImage: $0) }
    }

    /// A slime that blinks on its own, so a static window still feels
    /// inhabited rather than illustrated.
    struct Portrait: View {
        var stage: Int
        var height: CGFloat = 26
        var animated = true

        @State private var blinking = false

        var body: some View {
            Group {
                if let image = SlimeDecor.image(stage: stage, blinking: blinking && animated) {
                    image.resizable().scaledToFit()
                } else {
                    // Artwork missing: draw nothing rather than a stand-in
                    // that would misreport how full a group is.
                    Color.clear
                }
            }
            .frame(width: height * SlimeDecor.aspectRatio, height: height)
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

    /// The slime at the size the menu bar draws it, for explaining the icon.
    struct Inline: View {
        var stage: Int
        var body: some View {
            Portrait(stage: stage, height: 18, animated: false)
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
        HStack(spacing: 9) {
            SlimeDecor.Portrait(stage: SlimeRenderer.stage(forHiddenCount: count), height: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(title) (\(count))")
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

/// Empty-state panel with a slime standing in for an illustration.
struct SlimeEmptyState: View {
    var stage: Int = 1
    var message: String

    var body: some View {
        HStack(spacing: 10) {
            SlimeDecor.Portrait(stage: stage, height: 30)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
