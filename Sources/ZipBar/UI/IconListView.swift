import SwiftUI
import AppKit
import ZipBarKit

/// Shows what is in the menu bar, split into what the user can see and what
/// is currently hidden.
///
/// The app cannot move these icons — macOS reports every status item's
/// position as read-only, so reordering stays a ⌘-drag the user performs.
/// What the app can do is name them, say which side of the separator each one
/// is on, and open one without unhiding it. The UI is built around that
/// division rather than offering move controls that would quietly fail.
struct IconListView: View {
    @ObservedObject var inventory: MenuBarInventory

    var body: some View {
        Group {
            if inventory.isAuthorized {
                content
            } else {
                permissionGate
            }
        }
        .onAppear { inventory.refresh() }
    }

    // MARK: - Permission

    private var permissionGate: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("어떤 아이콘이 메뉴바에 있는지 보려면 접근성 권한이 필요합니다")
                .font(.headline)
            Text("macOS 26은 상태 아이템을 제어 센터가 대신 표시해서, 권한 없이는 "
                 + "어느 아이콘이 어느 앱 것인지 알 수 없습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("접근성 권한 요청") {
                inventory.requestAuthorization()
            }
            .buttonStyle(.borderedProminent)
            Button("이미 허용했다면 다시 확인") { inventory.refresh() }
                .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var content: some View {
        VStack(spacing: 0) {
            List {
                section(
                    "숨겨진 아이콘", systemImage: "eye.slash", items: inventory.hidden,
                    empty: "숨겨진 아이콘이 없습니다. 그룹을 접으면 구분자 왼쪽 아이콘이 여기로 옮겨집니다."
                )
                section(
                    "보이는 아이콘", systemImage: "eye", items: inventory.visible,
                    empty: "표시 중인 아이콘이 없습니다."
                )
            }

            Divider()
            footer
        }
    }

    @ViewBuilder
    private func section(
        _ title: String, systemImage: String, items: [MenuBarInventory.Item], empty: String
    ) -> some View {
        Section {
            if items.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    row(item)
                }
            }
        } header: {
            Label("\(title) (\(items.count))", systemImage: systemImage)
        }
    }

    private func row(_ item: MenuBarInventory.Item) -> some View {
        HStack(spacing: 10) {
            appIcon(for: item)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.ownerName)
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let frame = item.frame, item.presence == .visible {
                Text("x \(Int(frame.minX))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            // Pressing works on hidden items too, which is the one thing the
            // app can do for an icon it cannot move.
            Button("열기") { inventory.press(item) }
                .buttonStyle(.borderless)
                .help("\(item.ownerName) 아이콘을 클릭합니다")
        }
        .padding(.vertical, 2)
    }

    private func appIcon(for item: MenuBarInventory.Item) -> Image {
        if let pid = item.processIdentifier,
           let app = NSRunningApplication(processIdentifier: pid),
           let icon = app.icon {
            return Image(nsImage: icon).resizable()
        }
        return Image(systemName: "app.dashed").resizable()
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("아이콘을 그룹에 넣고 빼는 것은 앱이 대신 할 수 없습니다. "
                 + "macOS가 상태 아이템의 위치를 읽기 전용으로만 공개하기 때문입니다. "
                 + "⌘를 누른 채 아이콘을 구분자(‖) 왼쪽으로 끌면 숨겨지고, 오른쪽으로 끌면 다시 보입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button {
                inventory.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("다시 검사")
        }
        .padding(10)
    }
}
