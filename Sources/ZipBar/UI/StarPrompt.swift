import SwiftUI
import AppKit
import ZipBarKit

/// The ask for a GitHub star.
///
/// Deliberately hard to be annoyed by. It stays quiet until the panel has
/// been opened `threshold` times — asking someone to vouch for a tool they
/// have used twice is asking them to guess — and once they have either
/// starred or waved it away it never appears again. There is no "later",
/// because a "later" that comes back is the thing people hate.
@MainActor
final class StarPrompt: ObservableObject {

    enum State: String {
        case waiting     // not used enough yet
        case asking
        case done        // went to GitHub
        case dismissed   // said no
    }

    private static let opensKey = "com.zipbar.panelOpens"
    private static let stateKey = "com.zipbar.starPrompt"
    private static let starsKey = "com.zipbar.stargazers"

    /// Five openings. Enough that the app has done its job a few times, few
    /// enough that it happens in the first days rather than never.
    static let threshold = 5

    @Published private(set) var state: State
    @Published var stars: Int?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.stateKey) ?? State.waiting.rawValue
        self.state = State(rawValue: stored) ?? .waiting
        let count = defaults.integer(forKey: Self.starsKey)
        self.stars = count > 0 ? count : nil
    }

    var shouldAsk: Bool { state == .asking }

    /// Counted per panel opening, not per launch: a machine left on for a
    /// week would otherwise never advance past one.
    func recordPanelOpened() {
        guard state == .waiting else { return }
        let opens = defaults.integer(forKey: Self.opensKey) + 1
        defaults.set(opens, forKey: Self.opensKey)
        if opens >= Self.threshold { move(to: .asking) }
    }

    func accepted() {
        CreatorLinks.open(CreatorLinks.repo)
        move(to: .done)
    }

    func dismissed() { move(to: .dismissed) }

    func remember(stars: Int) {
        defaults.set(stars, forKey: Self.starsKey)
        self.stars = stars
    }

    private func move(to next: State) {
        state = next
        defaults.set(next.rawValue, forKey: Self.stateKey)
    }
}

/// The strip itself. Two targets: the ask, and the way out of it.
struct StarPromptView: View {
    @ObservedObject var prompt: StarPrompt
    /// The live count when a check has returned one, falling back to the last
    /// one stored. Passed in rather than read off the prompt so a fresh
    /// launch shows the number as soon as it lands.
    var stars: Int?

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button { prompt.accepted() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.yellow)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("쓸 만하셨다면 GitHub에 별 하나 부탁드립니다"))
                            .font(.system(size: 12, weight: .medium))
                        Text(starsLine)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(CreatorLinks.repo)

            // No "remind me later". The reminder that comes back is the part
            // people resent; this closes the subject for good.
            Button { prompt.dismissed() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("다시 묻지 않습니다"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(hovering ? Color.yellow.opacity(0.16) : Color.yellow.opacity(0.10))
        .onHover { hovering = $0 }
    }

    private var starsLine: String {
        // Stated only when it is known and not zero. "0 stars" reads as a
        // plea rather than an invitation.
        if let stars = stars ?? prompt.stars, stars > 0 {
            return L("무료로 쓰는 오픈소스입니다 · 지금 별 %@개", "\(stars)")
        }
        return L("무료로 쓰는 오픈소스입니다 · 한 번만 눌러 주시면 됩니다")
    }
}
