import SwiftUI
import ZipBarKit

enum SettingsTab: Hashable {
    case icons
    case groups
    case onboarding
    case diagnostics
}

struct SettingsView: View {
    @ObservedObject var engine: MenuBarEngine
    @StateObject private var inventory = MenuBarInventory()
    @State private var tab: SettingsTab

    init(engine: MenuBarEngine, initialTab: SettingsTab = .icons) {
        self.engine = engine
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            CapabilityBanner(capabilities: engine.capabilities)

            TabView(selection: $tab) {
                IconListView(inventory: inventory, engine: engine)
                    .tabItem { Label("아이콘", systemImage: "menubar.rectangle") }
                    .tag(SettingsTab.icons)

                GroupListView(engine: engine)
                    .tabItem { Label("그룹", systemImage: "square.stack.3d.up") }
                    .tag(SettingsTab.groups)

                OnboardingView()
                    .tabItem { Label("사용법", systemImage: "hand.point.up.left") }
                    .tag(SettingsTab.onboarding)

                DiagnosticsView(capabilities: engine.capabilities)
                    .tabItem { Label("진단", systemImage: "stethoscope") }
                    .tag(SettingsTab.diagnostics)
            }
            .padding(12)
        }
        .frame(minWidth: 600, minHeight: 440)
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
            return "스페이서 백엔드로 동작 중 — 권한 없이 그룹 접기/펴기가 가능합니다."
        case .menuServiceBridge:
            return "브릿지 백엔드로 동작 중 — 열거·이동·원격 클릭까지 가능합니다."
        case .degraded:
            return "현재 macOS 버전에서 동작하는 백엔드를 찾지 못했습니다."
        }
    }
}

struct DiagnosticsView: View {
    let capabilities: Capabilities

    private var rows: [(String, Bool)] {
        [
            ("숨기기", capabilities.canHide),
            ("아이템 열거", capabilities.canEnumerate),
            ("순서 이동", capabilities.canMove),
            ("원격 클릭", capabilities.canClickRemotely),
            ("아이콘 캡처", capabilities.canCapture),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("현재 백엔드: \(capabilities.backend.rawValue)")
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
            Text("터미널에서 `zipbar-probe capabilities`를 실행하면 각 백엔드가 이 macOS에서 실제로 무엇을 반환하는지 확인할 수 있습니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
