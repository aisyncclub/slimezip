import SwiftUI
import AppKit
import ZipBarKit

/// Shows what the slime is holding, what is still out in the open, and lets
/// the user move icons between the two.
///
/// Moving works by rewriting where macOS remembers each icon, which only takes
/// effect when the owning app next starts — see `MenuBarArranger`. That delay
/// is the honest shape of the feature, so the UI states it rather than letting
/// a click look like it did nothing.
struct IconListView: View {
    @ObservedObject var inventory: MenuBarInventory
    @ObservedObject var engine: MenuBarEngine

    /// A written position waiting on its app to restart.
    private struct Pending: Identifiable {
        let id: String
        let item: MenuBarInventory.Item
        let plan: MenuBarArranger.Plan
        let previous: Double?
    }

    @State private var pending: [Pending] = []
    @State private var restartTarget: Pending?
    @State private var problem: String?

    var body: some View {
        Group {
            if inventory.isAuthorized {
                content
            } else {
                permissionGate
            }
        }
        .onAppear { inventory.refresh() }
        .confirmationDialog(
            restartTarget.map { "\($0.item.ownerName)을(를) 재시작할까요?" } ?? "",
            isPresented: Binding(
                get: { restartTarget != nil },
                set: { if !$0 { restartTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("재시작") { performRestart() }
            Button("취소", role: .cancel) { restartTarget = nil }
        } message: {
            Text("아이콘 위치는 앱이 시작할 때 읽힙니다. 저장하지 않은 작업이 있으면 "
                 + "그 앱이 먼저 물어봅니다.")
        }
        .alert("옮기지 못했습니다", isPresented: Binding(
            get: { problem != nil }, set: { if !$0 { problem = nil } }
        )) {
            Button("확인", role: .cancel) { problem = nil }
        } message: {
            Text(problem ?? "")
        }
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
                if !pending.isEmpty { pendingSection }
                if !inventory.misplaced.isEmpty { todoSection }

                section(
                    "슬라임이 물고 있는 것", systemImage: "eye.slash",
                    items: inventory.hidden, moveTo: .visible,
                    empty: "아직 아무것도 물고 있지 않습니다. 아래에서 넣고 싶은 아이콘의 "
                         + "넣기를 누르세요."
                )
                section(
                    "넣을 수 있는 것", systemImage: "eye",
                    items: inventory.visible, moveTo: .hidden,
                    empty: "메뉴바에 보이는 아이콘이 없습니다."
                )
            }
            Divider()
            footer
        }
    }

    /// Moves that are written but not yet in effect. Kept at the top because
    /// a click that appears to have done nothing is the thing most likely to
    /// send the user looking for a bug.
    private var pendingSection: some View {
        Section {
            ForEach(pending) { entry in
                HStack(spacing: 10) {
                    appIcon(for: entry.item).frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.item.ownerName)
                        Text(entry.plan.side == .hidden ? "넣기 예약됨" : "꺼내기 예약됨")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("되돌리기") { undo(entry) }
                        .buttonStyle(.borderless)
                    Button("지금 재시작") { restartTarget = entry }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.vertical, 1)
            }
        } header: {
            Label("재시작하면 적용됩니다 (\(pending.count))", systemImage: "clock.arrow.circlepath")
        }
    }

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
            Label("옮겨야 할 것 (\(inventory.misplaced.count))",
                  systemImage: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func section(
        _ title: String, systemImage: String,
        items: [MenuBarInventory.Item], moveTo side: MenuBarArranger.Side,
        empty: String
    ) -> some View {
        Section {
            if items.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(items) { item in row(item, moveTo: side) }
            }
        } header: {
            Label("\(title) (\(items.count))", systemImage: systemImage)
        }
    }

    private func row(_ item: MenuBarInventory.Item, moveTo side: MenuBarArranger.Side) -> some View {
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

            // Pressing reaches a hidden icon without unhiding it.
            Button("열기") { inventory.press(item) }
                .buttonStyle(.borderless)
                .help("\(item.ownerName) 아이콘을 클릭합니다")

            if inventory.canMove(item) {
                Button(side == .hidden ? "넣기" : "꺼내기") { move(item, to: side) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(pending.contains { $0.id == item.preferenceKey })
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .help("이 아이콘은 앱을 특정할 수 없어 옮길 수 없습니다")
            }
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
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text("넣기·꺼내기는 macOS가 아이콘 위치를 기억하는 값을 고쳐 씁니다. "
                 + "그 값은 앱이 시작할 때 읽히므로 해당 앱을 재시작해야 적용됩니다. "
                 + "직접 옮기려면 ⌘를 누른 채 경계 왼쪽으로 끌면 숨겨집니다.")
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

    // MARK: - Actions

    private func move(_ item: MenuBarInventory.Item, to side: MenuBarArranger.Side) {
        guard let boundary = engine.boundaryPosition() else {
            problem = "경계 위치를 아직 알 수 없습니다. 설정을 한 번 닫았다 열어보세요."
            return
        }
        guard let result = inventory.move(item, to: side, boundaryPosition: boundary) else {
            problem = "\(item.ownerName)의 아이콘 위치를 고쳐 쓸 수 없었습니다."
            return
        }
        pending.append(Pending(
            id: item.preferenceKey, item: item,
            plan: result.plan, previous: result.previous))
    }

    private func undo(_ entry: Pending) {
        inventory.undo(entry.plan, previous: entry.previous)
        inventory.setDesired(nil, for: entry.item)
        pending.removeAll { $0.id == entry.id }
    }

    private func performRestart() {
        guard let entry = restartTarget else { return }
        restartTarget = nil
        inventory.restart(entry.item) { outcome in
            switch outcome {
            case .restarted, .notRunning:
                pending.removeAll { $0.id == entry.id }
            case .refusedToQuit:
                problem = "\(entry.item.ownerName)이(가) 종료를 거부했습니다. "
                    + "저장하지 않은 작업이 있는지 확인한 뒤 다시 시도하세요."
            case .failedToRelaunch:
                problem = "\(entry.item.ownerName)을(를) 다시 실행하지 못했습니다. "
                    + "직접 실행하면 옮긴 위치가 적용됩니다."
            }
        }
    }
}
