import SwiftUI
import AppKit

/// Who made this, where to find them, and what this copy is.
///
/// Its own section rather than a line in the footer. The welcome page carries
/// a one-card mention because that page is an introduction; this is the page
/// somebody opens on purpose, so it holds every link, the version, and the
/// update check in one place instead of scattering them.
struct CreatorView: View {
    @ObservedObject var config: RemoteConfig
    var onUpdate: () -> Void

    private struct Destination {
        let title: String
        let detail: String
        let url: String
        let symbol: String
        let logo: String?
    }

    private let destinations: [Destination] = [
        Destination(title: "싱크마켓", detail: "AI 스킬·템플릿·자료 — 오픈베타 무료 배포 중",
                    url: CreatorLinks.syncMarket, symbol: "bag", logo: "syncmarket"),
        Destination(title: "링크 모음", detail: "커뮤니티, 강의, 자료실까지 한 곳에",
                    url: CreatorLinks.home, symbol: "link", logo: nil),
        Destination(title: "유튜브", detail: "@AISyncClub",
                    url: CreatorLinks.youTube, symbol: "play.rectangle", logo: nil),
        Destination(title: "쓰레드", detail: "@ai_sync_club",
                    url: CreatorLinks.threads, symbol: "at", logo: nil),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                identity
                links
                Divider()
                appInfo
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var identity: some View {
        HStack(alignment: .top, spacing: 16) {
            SlimeDecor.Portrait(stage: 3, height: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text("Ai싱크클럽")
                    .font(.system(size: 24, weight: .bold))
                Text("싱크 제작")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("AI를 실제 업무에 붙이는 사람들의 커뮤니티입니다. "
                     + "SlimeZIP은 거기서 나온 도구 중 하나고, 무료이며 소스가 공개돼 있습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private var links: some View {
        VStack(spacing: 8) {
            ForEach(destinations, id: \.title) { place in
                DestinationRow(
                    title: place.title, detail: place.detail,
                    url: place.url, symbol: place.symbol, logo: place.logo)
            }
        }
    }

    private var appInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이 앱")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SlimeZIP \(config.currentVersion)")
                        .font(.headline)
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if config.updateAvailable {
                    Button("업데이트", action: onUpdate)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(config.isChecking ? "확인 중…" : "업데이트 확인") {
                        config.checkNow()
                    }
                    .disabled(config.isChecking)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.045)))

            Button("릴리스 기록 보기") { CreatorLinks.open(RemoteConfig.releasesPage) }
                .buttonStyle(.link)
                .font(.callout)
        }
    }

    private var statusLine: String {
        if config.isChecking { return "확인 중…" }
        if let latest = config.latestVersion, config.updateAvailable {
            return "새 버전 \(latest)이 나와 있습니다"
        }
        return config.lastCheckedAt == nil
            ? "무료 · 오픈소스 · macOS 14 이상"
            : "최신 버전입니다"
    }
}

/// One link, sized like a row rather than a word.
private struct DestinationRow: View {
    let title: String
    let detail: String
    let url: String
    let symbol: String
    let logo: String?

    @State private var hovering = false

    private var mark: NSImage? {
        guard let logo,
              let file = Bundle.main.url(forResource: logo, withExtension: "png",
                                         subdirectory: "Brand")
        else { return nil }
        return NSImage(contentsOf: file)
    }

    var body: some View {
        Button { CreatorLinks.open(url) } label: {
            HStack(spacing: 12) {
                Group {
                    if let mark {
                        Image(nsImage: mark)
                            .resizable()
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(hovering ? 0.075 : 0.04)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(url)
    }
}
