import SwiftUI
import AppKit

/// Where the app points people, in one place.
enum CreatorLinks {
    static let home = "https://litt.ly/aisyncclub"
    static let youTube = "https://www.youtube.com/@AISyncClub"
    static let threads = "https://www.threads.com/@ai_sync_club"
    /// The marketplace. Separate from `home`: the footer link points at
    /// the link hub, the banner points at the thing being advertised.
    static let syncMarket = "https://aisyncclub.com/market"
    /// The repository. Where a star is left, and where the source is read.
    static let repo = "https://github.com/aisyncclub/slimezip"

    static func open(_ string: String) {
        // The default browser, not an in-app view: these go somewhere else,
        // and a menu bar utility has no business hosting a web view.
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// The two links in the panel footer, and the marks that stand for them.
///
/// YouTube is drawn: a rounded badge with the play triangle punched out is
/// unmistakable and takes four points to describe.
///
/// Threads is not drawn. Its mark is a single specific stroke, and three
/// hand-tuned attempts all came out as a blob that read as neither Threads
/// nor anything else — a bad logo is worse than no logo, and it would be an
/// approximation of somebody else's trademark besides. The `at` symbol is
/// what the real mark is built from, Apple draws it crisply at any size, and
/// beside a play badge with a "쓰레드" tooltip it reads as what it is.
enum SocialMark {
    case youtube
    case threads
}

/// A single tappable mark in the panel footer.
struct MarkButton: View {
    let mark: SocialMark
    let url: String
    let label: String

    @State private var hovering = false

    var body: some View {
        Button { CreatorLinks.open(url) } label: {
            glyph
                .frame(width: 22, height: 18)
                // Grey until pointed at. Two brand colours sitting in the
                // footer would pull the eye off the rows, which are what the
                // panel is for.
                .foregroundStyle(hovering ? tint : Color.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(label) — \(url)")
        .accessibilityLabel(label)
    }

    private var tint: Color {
        switch mark {
        case .youtube: return Color(red: 1.0, green: 0.0, blue: 0.13)
        case .threads: return .primary
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch mark {
        case .youtube:
            YouTubeMark()
                .fill(style: FillStyle(eoFill: true))
                .frame(width: 20, height: 14)
        case .threads:
            Image(systemName: "at")
                .font(.system(size: 16, weight: .semibold))
        }
    }
}

/// Rounded rectangle with the play triangle punched out of it.
///
/// One path filled even-odd, so the triangle is a hole rather than a second
/// shape painted in the background colour — the footer sits on the popover's
/// material, which has no flat colour to paint with.
struct YouTubeMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.height * 0.30
        path.addRoundedRect(in: rect,
                            cornerSize: CGSize(width: radius, height: radius),
                            style: .continuous)

        let w = rect.width, h = rect.height
        var play = Path()
        play.move(to: CGPoint(x: rect.minX + w * 0.395, y: rect.minY + h * 0.26))
        play.addLine(to: CGPoint(x: rect.minX + w * 0.395, y: rect.minY + h * 0.74))
        play.addLine(to: CGPoint(x: rect.minX + w * 0.675, y: rect.minY + h * 0.50))
        play.closeSubpath()
        path.addPath(play)
        return path
    }
}
