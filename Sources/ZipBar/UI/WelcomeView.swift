import SwiftUI
import AppKit
import ZipBarKit

/// The first thing a new user sees: what this is, how to use it, who made it.
///
/// Settings used to open straight onto the icon list — a table of app names
/// with buttons beside them, shown to somebody who does not yet know what the
/// buttons do or what the slime in their menu bar is. The tutorial was there,
/// but on a fourth tab nobody had a reason to press.
///
/// So the explanation goes first and the tabs get one page fewer: this page
/// absorbed the old 사용법 tab rather than sitting beside it, because two tabs
/// that both explain the app is the problem, not the fix.
struct WelcomeView: View {
    @ObservedObject var engine: MenuBarEngine
    var onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                identity
                quickStart
                Divider()
                OnboardingContent()
                Divider()
                creator
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Identity

    private var identity: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text("SlimeZIP")
                    .font(.system(size: 28, weight: .bold))
                Text("메뉴바에 아이콘이 넘칠 때, 슬라임 한 마리가 나머지를 물고 있습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(versionLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    /// Read from the bundle rather than typed here, so it cannot drift out of
    /// step with what was actually shipped.
    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        return "버전 \(version) · macOS 14 이상 · 무료 · 오픈소스"
    }

    // MARK: - Quick start

    private struct Move {
        let number: String
        let title: String
        let detail: String
    }

    private let moves: [Move] = [
        Move(number: "1", title: "슬라임을 누릅니다",
             detail: "메뉴바 오른쪽의 슬라임을 클릭하면 지금 떠 있는 아이콘이 전부 나옵니다."),
        Move(number: "2", title: "넣기 · 꺼내기",
             detail: "감추고 싶은 것 옆의 버튼을 누릅니다. 여러 개를 한 번에 골라도 됩니다."),
        Move(number: "3", title: "적용은 한 번뿐",
             detail: "그 앱을 한 번만 재시작하면 자리가 정해집니다. 이후로는 클릭 즉시 됩니다."),
    ]

    private var quickStart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3단계면 끝입니다")
                .font(.title3.weight(.semibold))

            HStack(alignment: .top, spacing: 10) {
                ForEach(moves, id: \.number) { move in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(move.number)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.accentColor))
                        Text(move.title)
                            .font(.headline)
                        Text(move.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.045)))
                }
            }

            HStack(spacing: 10) {
                Button("아이콘 목록 열기", action: onStart)
                    .buttonStyle(.borderedProminent)
                // The banner at the top of the window says the same thing in
                // backend terms; here it is said in terms of what the reader
                // will and will not be able to do.
                if !engine.capabilities.canEnumerate {
                    Label("손쉬운 사용 권한을 켜야 목록에 이름이 나옵니다",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Creator

    private var creator: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("만든 곳")
                .font(.title3.weight(.semibold))

            HStack(spacing: 14) {
                SlimeDecor.Portrait(stage: 3, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ai싱크클럽")
                        .font(.headline)
                    Text("싱크 제작")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button("링크 모음") { CreatorLinks.open(CreatorLinks.home) }
                MarkButton(mark: .youtube, url: CreatorLinks.youTube, label: "유튜브")
                MarkButton(mark: .threads, url: CreatorLinks.threads, label: "쓰레드")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.045)))
        }
    }
}
