import SwiftUI
import AppKit
import ZipBarKit

/// The strip along the bottom of the panel.
///
/// Editable without a rebuild, because the thing it advertises changes far
/// more often than the app does. It lives in the app's own preferences:
///
///     defaults write com.zipbar.ZipBar com.zipbar.promo -string \
///       '{"badge":"Ai싱크클럽","text":"…","url":"https://…","enabled":true}'
///
/// Anything missing falls back to the built-in copy, and `enabled:false`
/// removes the strip entirely — a banner with no way to switch it off is a
/// banner the user comes to resent.
struct PromoBanner: Codable, Equatable {
    var badge: String
    var text: String
    var url: String
    var enabled: Bool
    /// Name of a PNG in the bundle's Brand folder, drawn in place of the
    /// badge pill. Absent or missing on disk falls back to the pill, so a
    /// remote config can name art this build does not ship without
    /// leaving a hole in the strip.
    var logo: String?
    /// English copy, when the config carries it. Optional so an older config
    /// file — or one written by somebody who only cares about Korean — still
    /// decodes, and simply shows the Korean to everyone.
    var badge_en: String?
    var text_en: String?

    /// What to actually draw, for the language in use.
    var resolvedBadge: String { L10n.current == .en ? (badge_en ?? badge) : badge }
    var resolvedText: String { L10n.current == .en ? (text_en ?? text) : text }

    static let defaultsKey = "com.zipbar.promo"

    static let fallback = PromoBanner(
        badge: L("싱크마켓"),
        text: L("오픈베타 · 무료 스킬 배포 중"),
        url: CreatorLinks.syncMarket,
        enabled: true,
        logo: "syncmarket",
        badge_en: "SyncMarket",
        text_en: "Open beta · free skills")

}

/// Draws it. One target, the whole strip, same as the credit row above it.
struct PromoBannerView: View {
    let promo: PromoBanner

    @State private var hovering = false

    private var brandImage: NSImage? {
        guard let name = promo.logo,
              let url = Bundle.main.url(forResource: name, withExtension: "png",
                                        subdirectory: "Brand")
        else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        Button { CreatorLinks.open(promo.url) } label: {
            HStack(spacing: 8) {
                if let mark = brandImage {
                    Image(nsImage: mark)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(promo.resolvedBadge)
                        .font(.system(size: 11, weight: .bold))
                } else {
                    Text(promo.resolvedBadge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor))
                }

                Text(promo.resolvedText)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    // Shrinks rather than truncates: the whole point of the
                    // line is the offer at the end of it.
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(hovering
                        ? Color.accentColor.opacity(0.14)
                        : Color.accentColor.opacity(0.08))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(promo.url)
    }
}
