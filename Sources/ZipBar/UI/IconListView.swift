import SwiftUI
import AppKit
import ZipBarKit

/// Shows what the slime is holding, what is still out in the open, and which
/// icons are not where the user asked them to be.
///
/// There are no move controls, because there is no move. macOS reports every
/// status item's position as read-only and ignores a synthesised ⌘-drag, so
/// an icon changes sides only when the user drags it. What the app adds is
/// knowing which ones are wrong: naming two icons out of thirty is the useful
/// half of a job it cannot finish.
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
            Button("접근성 권한 요청") { inventory.requestAuthorization() }
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
                if !inventory.misplaced.isEmpty { todoSection }

                section(
                    "슬라임이 물고 있는 것", systemImage: "eye.slash", items: inventory.hidden,
                    empty: "아직 아무것도 물고 있지 않습니다. 숨기고 싶은 아이콘을 "
                         + "⌘를 누른 채 슬라임 왼쪽으로 끌어보세요."
                )
                section(
                    "넣을 수 있는 것", systemImage: "eye", items: inventory.visible,
                    empty: "메뉴바에 보이는 아이콘이 없습니다."
                )
            }
            Divider()
            footer
        }
    }

    /// Only the icons that disagree with a stated preference. Icons the user
    /// has not ruled on stay out of it — silence is not a request.
    private var todoSection: some View {
        Section {
            ForEach(inventory.misplaced) { entry in
                HStack(spacing: 10) {
                    appIcon(for: entry.item).frame(width: 18, height: 18)
                    Text(entry.item.ownerName)
                    Spacer()
                    Text(entry.instruction)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 1)
            }
        } header: {
            Label("옮겨야 할 것 (\(inventory.misplaced.count))", systemImage: "exclamationmark.triangle")
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
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(items) { item in row(item) }
            }
        } header: {
            Label("\(title) (\(items.count))", systemImage: systemImage)
        }
    }

    private func row(_ item: MenuBarInventory.Item) -> some View {
        HStack(spacing: 10) {
            appIcon(for: item).frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(item.ownerName)
                    if inventory.activeIDs.contains(item.id) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.orange)
                            .help("숨겨진 사이에 이 아이콘이 바뀌었습니다")
                    }
                }
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
            preferenceControl(for: item)

            // Pressing reaches a hidden icon without unhiding it, which is
            // the one thing the app can still do for an icon it cannot move.
            Button("열기") { inventory.press(item) }
                .buttonStyle(.borderless)
                .help("\(item.ownerName) 아이콘을 클릭합니다")
        }
        .padding(.vertical, 2)
    }

    private func preferenceControl(for item: MenuBarInventory.Item) -> some View {
        let current = inventory.desired(for: item)
        return Menu {
            Button { inventory.setDesired(.visible, for: item) } label: {
                Label("남겨두기", systemImage: current == .visible ? "checkmark" : "eye")
            }
            Button { inventory.setDesired(.hidden, for: item) } label: {
                Label("숨기기", systemImage: current == .hidden ? "checkmark" : "eye.slash")
            }
            Divider()
            Button("정하지 않음") { inventory.setDesired(nil, for: item) }
        } label: {
            switch current {
            case .visible: Text("남겨두기").foregroundStyle(.tint)
            case .hidden:  Text("숨기기").foregroundStyle(.tint)
            case nil:      Text("—").foregroundStyle(.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("이 아이콘을 어디에 두고 싶은지 정합니다")
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
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text("아이콘을 옮기는 것은 앱이 대신 할 수 없습니다 — macOS가 상태 아이템의 "
                 + "위치를 읽기 전용으로만 공개합니다. ⌘를 누른 채 슬라임 왼쪽으로 끌면 "
                 + "숨겨지고, 오른쪽으로 끌면 다시 보입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button { inventory.refresh() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("다시 검사")
        }
        .padding(10)
    }
}
