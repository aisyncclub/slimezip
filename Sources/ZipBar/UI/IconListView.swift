import SwiftUI
import AppKit
import ZipBarKit

/// The whole arrangement in two lists: what is hidden, what is visible, and
/// one button per icon to move it across.
///
/// Earlier versions had four sections and three controls per row — a
/// preference dropdown, a move button, and a to-do list telling the user to
/// ⌘-drag. All of it collapsed into one action once moves became real: the
/// button states the intent, the preference follows it, and a drag the user
/// makes by hand wins over anything stored (see `MenuBarInventory.reconcile`).
///
/// A move only takes effect when the owning app restarts, so a row with one
/// waiting shows that state inline — where the click happened — instead of in
/// a separate list the user has to correlate.
struct IconListView: View {
    @ObservedObject var inventory: MenuBarInventory
    @ObservedObject var engine: MenuBarEngine

    private struct RestartRequest: Identifiable {
        let id: String
        let items: [MenuBarInventory.Item]
        var names: String { items.map(\.ownerName).joined(separator: ", ") }
    }

    @State private var restartRequest: RestartRequest?
    @State private var problem: String?

    var body: some View {
        Group {
            if inventory.isAuthorized {
                content
            } else {
                permissionGate
            }
        }
        .onAppear {
            inventory.boundaries = engine.boundaries()
            inventory.refresh()
        }
        .confirmationDialog(
            restartRequest.map { L("재시작: %@", $0.names) } ?? "",
            isPresented: Binding(
                get: { restartRequest != nil },
                set: { if !$0 { restartRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L("재시작")) { performRestarts() }
            Button(L("취소"), role: .cancel) { restartRequest = nil }
        } message: {
            Text(L("아이콘 위치는 앱이 시작할 때 읽히므로, 옮긴 위치는 재시작해야 적용됩니다. 저장하지 않은 작업이 있는 앱은 스스로 거부할 수 있습니다."))
        }
        .alert(L("문제가 있었습니다"), isPresented: Binding(
            get: { problem != nil }, set: { if !$0 { problem = nil } }
        )) {
            Button(L("확인"), role: .cancel) { problem = nil }
        } message: {
            Text(problem ?? "")
        }
    }

    // MARK: - Permission

    /// Re-checks the grant while this gate is on screen.
    ///
    /// The user flips the toggle in System Settings, not here, so the moment
    /// of success is invisible to us — polling is the only way the gate can
    /// dismiss itself instead of demanding another click.
    private let grantPoll = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var permissionGate: some View {
        VStack(spacing: 12) {
            SlimeDecor.Portrait(stage: 1, height: 46)
                .opacity(0.65)
            Text(L("어떤 아이콘이 메뉴바에 있는지 보려면 접근성 권한이 필요합니다"))
                .font(.headline)
            Text(L("macOS 26은 상태 아이템을 제어 센터가 대신 표시해서, 권한 없이는 어느 아이콘이 어느 앱 것인지 알 수 없습니다."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button(L("접근성 권한 요청")) { inventory.requestAuthorization() }
                .buttonStyle(.borderedProminent)

            // A grant given while the app is running does not reach this
            // process — a relaunch is the fix, so it is offered here rather
            // than left for the user to discover.
            VStack(spacing: 4) {
                Text(L("이미 허용했는데 이 화면이 남아 있다면, 실행 중이던 앱에는 권한이 늦게 전달됩니다. 재시작하면 바로 적용됩니다."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                Button(L("SlimeZIP 재시작")) { SelfRelauncher.relaunch() }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(grantPoll) { _ in
            if !inventory.isAuthorized { inventory.refresh() }
        }
    }

    // MARK: - Content

    /// Items with a move waiting on a restart, in list order.
    private var waiting: [MenuBarInventory.Item] {
        (inventory.hidden + inventory.visible)
            .filter { inventory.pendingMove(for: $0) != nil }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if !waiting.isEmpty { applyBar }

            List {
                // One section per group, then the icons that stay on screen.
                // Driven by the live boundaries rather than a fixed pair, so
                // adding a group in the 그룹 tab shows up here immediately.
                ForEach(Array(inventory.boundaries.enumerated()), id: \.offset) { index, boundary in
                    zoneSection(
                        title: boundary.name,
                        subtitle: boundary.behavior == .alwaysHidden
                            ? L("슬라임이 계속 물고 있습니다")
                            : L("슬라임을 누르면 여기가 열리고 닫힙니다"),
                        zone: .group(index),
                        empty: L("여기는 아직 비어 있습니다. 아래에서 넣어보세요."))
                }
                zoneSection(
                    title: L("밖에 나와 있는 것"),
                    subtitle: L("언제나 메뉴바에 보입니다"),
                    zone: .visible,
                    empty: L("메뉴바에 보이는 아이콘이 없습니다."))
            }
            Divider()
            footer
        }
    }

    /// One strip that finishes everything at once. Restarting apps is the
    /// tedious half of a move, so the moment anything is waiting the way to
    /// complete it all sits at the top, not per-row only.
    private var applyBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.orange)
            Text(L("%@개 이동이 재시작을 기다립니다", "\(waiting.count)"))
                .font(.callout)
            Spacer()
            Button(L("모두 적용")) {
                restartRequest = RestartRequest(
                    id: waiting.map(\.preferenceKey).joined(),
                    items: waiting)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.08))
    }

    @ViewBuilder
    private func zoneSection(
        title: String, subtitle: String, zone: MenuBarZone, empty: String
    ) -> some View {
        let entries = inventory.items(in: zone)
        Section {
            if entries.isEmpty {
                SlimeEmptyState(message: empty)
            } else {
                ForEach(entries) { item in zoneRow(item, currentZone: zone) }
            }
        } header: {
            ZoneHeader(title: title, subtitle: subtitle, count: entries.count)
        }
    }

    /// Destinations other than where the icon already is.
    private func destinations(besides current: MenuBarZone) -> [(MenuBarZone, String)] {
        var out: [(MenuBarZone, String)] = inventory.boundaries.enumerated().map {
            (.group($0.offset), $0.element.name)
        }
        out.append((.visible, L("밖으로 꺼내기")))
        return out.filter { $0.0 != current }
    }

    private func zoneRow(_ item: MenuBarInventory.Item, currentZone: MenuBarZone) -> some View {
        HStack(spacing: 10) {
            appIcon(for: item).frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(item.ownerName)
                    if inventory.activeIDs.contains(item.id) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.orange)
                            .help(L("숨겨진 사이에 이 아이콘이 바뀌었습니다"))
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

            if let record = inventory.pendingMove(for: item) {
                Text(record.side == .hidden ? L("숨김 예약") : L("표시 예약"))
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button(L("취소")) { inventory.cancelMove(for: item) }
                    .buttonStyle(.borderless)
                Button(L("재시작")) {
                    restartRequest = RestartRequest(id: item.preferenceKey, items: [item])
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button(L("열기")) { inventory.press(item) }
                    .buttonStyle(.borderless)
                    .help(L("%@ 아이콘을 클릭합니다 — 숨겨져 있어도 됩니다", item.ownerName))

                if inventory.canMove(item) {
                    let targets = destinations(besides: currentZone)
                    if targets.count == 1 {
                        // One destination is a button, not a menu: the common
                        // single-group case should stay one click.
                        Button(targets[0].1) { move(item, to: targets[0].0) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Menu(L("옮기기")) {
                            ForEach(Array(targets.enumerated()), id: \.offset) { _, target in
                                Button(target.1) { move(item, to: target.0) }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                } else {
                    Text("—")
                        .foregroundStyle(.tertiary)
                        .help(L("이 아이콘은 앱을 특정할 수 없어 옮길 수 없습니다"))
                }
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
            Text(L("숨기기·꺼내기는 아이콘의 자리를 옮기는 일이라 그 앱을 한 번 재시작해야 합니다. 자리가 정해진 뒤로는 슬라임 클릭만으로 즉시 감추고 꺼낼 수 있습니다. ⌘드래그로 직접 옮기면 재시작 없이 반영되며, 그 배치가 항상 우선합니다."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button { inventory.refresh() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(L("다시 검사"))
        }
        .padding(10)
    }

    // MARK: - Actions

    private func move(_ item: MenuBarInventory.Item, to zone: MenuBarZone) {
        guard !inventory.boundaries.isEmpty else {
            problem = L("경계 위치를 아직 알 수 없습니다. 설정을 한 번 닫았다 열어보세요.")
            return
        }
        if !inventory.move(item, toZone: zone) {
            problem = L("%@의 아이콘 위치를 고쳐 쓸 수 없었습니다.", item.ownerName)
        }
    }

    /// Restarts the requested apps one at a time. Sequential on purpose:
    /// quitting half the menu bar simultaneously turns the bar into a slot
    /// machine, and a single failure is easier to attribute when the apps go
    /// down one by one.
    private func performRestarts() {
        guard let request = restartRequest else { return }
        restartRequest = nil
        restartNext(Array(request.items))
    }

    private func restartNext(_ remaining: [MenuBarInventory.Item]) {
        guard let item = remaining.first else {
            inventory.refresh()
            return
        }
        inventory.restart(item) { outcome in
            switch outcome {
            case .restarted, .notRunning:
                break
            case .refusedToQuit:
                problem = L("%@이(가) 종료를 거부했습니다. 저장하지 않은 작업을 정리한 뒤 그 앱을 직접 재시작하면 적용됩니다.", item.ownerName)
            case .failedToRelaunch:
                problem = L("%@을(를) 다시 실행하지 못했습니다. 직접 실행하면 옮긴 위치가 적용됩니다.", item.ownerName)
            }
            restartNext(Array(remaining.dropFirst()))
        }
    }
}
