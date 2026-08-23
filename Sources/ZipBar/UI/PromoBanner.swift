import SwiftUI
import AppKit

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

    static let defaultsKey = "com.zipbar.promo"

    static let fallback = PromoBanner(
        badge: "Ai싱크클럽",
        text: "싱크마켓 오픈베타 · 무료 스킬 배포 중",
        url: CreatorLinks.home,
        enabled: true)

    static func load(from defaults: UserDefaults = .standard) -> PromoBanner {
        guard let raw = defaults.string(forKey: defaultsKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PromoBanner.self, from: data)
        else { return fallback }
        return decoded
    }
}

/// Draws it. One target, the whole strip, same as the credit row above it.
struct PromoBannerView: View {
    let promo: PromoBanner

    @State private var hovering = false

    var body: some View {
        Button { CreatorLinks.open(promo.url) } label: {
            HStack(spacing: 8) {
                Text(promo.badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))

                Text(promo.text)
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
