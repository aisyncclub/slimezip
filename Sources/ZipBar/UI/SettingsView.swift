import SwiftUI
import ZipBarKit

enum SettingsTab: Hashable {
    case welcome
    case icons
    case groups
    case creator
    case diagnostics
}

struct SettingsView: View {
    @ObservedObject var engine: MenuBarEngine
    @ObservedObject var config: RemoteConfig
    @StateObject private var inventory = MenuBarInventory()
    @State private var tab: SettingsTab

    var onUpdate: () -> Void

    init(engine: MenuBarEngine,
         config: RemoteConfig,
         initialTab: SettingsTab = .icons,
         onUpdate: @escaping () -> Void = {}) {
        self.engine = engine
        self.config = config
        self.onUpdate = onUpdate
        _tab = State(initialValue: initialTab)
    }

    private struct Section {
        let tab: SettingsTab
        let title: String
        let symbol: String
        let blurb: String
    }

    private let sections: [Section] = [
        Section(tab: .welcome, title: L("시작하기"), symbol: "sparkles",
                blurb: L("무엇인지, 어떻게 쓰는지")),
        Section(tab: .icons, title: L("아이콘"), symbol: "menubar.rectangle",
                blurb: L("넣고 빼기")),
        Section(tab: .groups, title: L("그룹"), symbol: "square.stack.3d.up",
                blurb: L("묶어서 관리")),
        Section(tab: .creator, title: L("제작자"), symbol: "person.2",
                blurb: L("Ai싱크클럽 · 싱크 제작")),
        Section(tab: .diagnostics, title: L("진단"), symbol: "stethoscope",
                blurb: L("이 맥에서 되는 것")),
    ]

    var body: some View {
        VStack(spacing: 0) {
            CapabilityBanner(capabilities: engine.capabilities)
            HStack(spacing: 0) {
                sidebar
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    /// A sidebar rather than `TabView`.
    ///
    /// The TabView this replaces drew no tab bar at all — the rendered view
    /// hierarchy went straight from the banner to the content, with no
    /// segmented control anywhere in it. Whatever the cause, the settings
    /// window had four pages and nothing on screen to reach three of them,
    /// which is most of why it was hard to follow. A sidebar built out of
    /// plain buttons cannot silently stop drawing itself.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(sections, id: \.tab) { section in
                Button { tab = section.tab } label: {
                    HStack(spacing: 9) {
                        Image(systemName: section.symbol)
                            .frame(width: 18)
                            .foregroundStyle(tab == section.tab ? Color.white : Color.accentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(section.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text(section.blurb)
                                .font(.caption2)
                                .foregroundStyle(tab == section.tab
                                                 ? Color.white.opacity(0.8)
                                                 : Color.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(tab == section.tab ? Color.white : Color.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 7)
                        .fill(tab == section.tab ? Color.accentColor : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(10)
        .frame(width: 184)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .welcome:
            WelcomeView(engine: engine) { tab = .icons }
        case .icons:
            IconListView(inventory: inventory, engine: engine).padding(12)
        case .groups:
            GroupListView(engine: engine).padding(12)
        case .creator:
            CreatorView(config: config, onUpdate: onUpdate)
        case .diagnostics:
            DiagnosticsView(capabilities: engine.capabilities).padding(18)
        }
    }
}

/// Always-visible statement of what the app can do on this machine.
///
/// The previous generation of menu bar managers failed quietly when macOS
/// changed underneath them, which is how they earned their reputation. ZipBar
/// says it out loud instead.
struct CapabilityBanner: View {
    let capabilities: Capabilities

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(headline)
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(tint.opacity(0.12))
    }

    private var icon: String {
        switch capabilities.backend {
        case .degraded: return "exclamationmark.triangle.fill"
        case .spacer: return "checkmark.circle.fill"
        case .menuServiceBridge: return "bolt.circle.fill"
        }
    }

    private var tint: Color {
        capabilities.backend == .degraded ? .orange : .green
    }

    private var headline: String {
        switch capabilities.backend {
        case .spacer:
            return L("스페이서 백엔드로 동작 중 — 권한 없이 그룹 접기/펴기가 가능합니다.")
        case .menuServiceBridge:
            return L("브릿지 백엔드로 동작 중 — 열거·이동·원격 클릭까지 가능합니다.")
        case .degraded:
            return L("현재 macOS 버전에서 동작하는 백엔드를 찾지 못했습니다.")
        }
    }
}

struct DiagnosticsView: View {
    let capabilities: Capabilities

    private var rows: [(String, Bool)] {
        [
            (L("숨기기"), capabilities.canHide),
            (L("아이템 열거"), capabilities.canEnumerate),
            (L("순서 이동"), capabilities.canMove),
            (L("원격 클릭"), capabilities.canClickRemotely),
            (L("아이콘 캡처"), capabilities.canCapture),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("현재 백엔드: %@", capabilities.backend.rawValue))
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(rows, id: \.0) { row in
                    GridRow {
                        Image(systemName: row.1 ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(row.1 ? Color.green : Color.secondary)
                        Text(row.0)
                    }
                }
            }

            if !capabilities.notes.isEmpty {
                Divider()
                ForEach(capabilities.notes, id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Said plainly and in one place. An app that quietly talks to a
            // server is an app people are right to distrust, and the setting
            // is worthless if nobody knows it exists.
            VStack(alignment: .leading, spacing: 4) {
                Label(L("인터넷 사용"), systemImage: "network")
                    .font(.headline)
                Text(L("여섯 시간에 한 번, 패널을 열 때만 두 곳을 읽습니다 — 새 버전이 나왔는지(GitHub 릴리스), 그리고 아래 띠에 띄울 문구입니다. 보내는 것은 없고, 아이콘 목록이나 사용 기록은 어디에도 올라가지 않습니다."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("끄려면: defaults write com.zipbar.ZipBar com.zipbar.checkForUpdates -bool NO"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }

            Divider()
            Text(L("터미널에서 `zipbar-probe capabilities`를 실행하면 각 백엔드가 이 macOS에서 실제로 무엇을 반환하는지 확인할 수 있습니다."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
