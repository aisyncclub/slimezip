import SwiftUI
import AppKit
import ZipBarKit

/// What clicking the slime opens: the icons, and one button each to put them
/// in or take them out.
///
/// Clicking used to just collapse and expand the group, which answered "let me
/// peek" but not "let me change what is in there" — that meant opening the
/// settings window, finding the row, and clicking again. Since choosing what
/// to hide is the whole point of the app, it belongs one click from the bar.
///
/// Deliberately not the settings list. This is a compact panel with one action
/// per row and no group management; the settings window stays as the place for
/// arranging groups and reading the diagnostics.
struct QuickPanelView: View {
    @ObservedObject var inventory: MenuBarInventory
    @ObservedObject var engine: MenuBarEngine

    var onOpenSettings: () -> Void
    var onToggle: () -> Void
    var onRevealAll: () -> Void
    var onRestart: ([MenuBarInventory.Item]) -> Void
    var onMoveSelf: (Double) -> Void
    var canMoveSelf: (Double) -> Bool

    /// Excludes always-hidden groups, which are shut by definition — counting
    /// them pinned this to true and left the button stuck on "펼치기".
    private var anyCollapsed: Bool { engine.isToggleableCollapsed }

    private var hasAlwaysHidden: Bool {
        engine.layout.groups.contains { $0.behavior == .alwaysHidden }
    }

    private var waiting: [MenuBarInventory.Item] {
        inventory.items.filter { inventory.pendingMove(for: $0) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(inventory.boundaries.enumerated()), id: \.offset) { index, boundary in
                        group(title: boundary.name, zone: .group(index))
                    }
                    group(title: "밖에 나와 있는 것", zone: .visible)
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 340)

            if !waiting.isEmpty {
                Divider()
                applyStrip
            }

            Divider()
            selfMoveRow
            Divider()
            footer
        }
        .frame(width: 300)
        // No refresh here: the app populates boundaries and collapse state
        // together before showing the panel, and re-reading only half of that
        // from the view would put the two out of step.
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            SlimeDecor.Portrait(
                stage: SlimeRenderer.stage(forHiddenCount: inventory.concealed.count),
                height: 26)
            VStack(alignment: .leading, spacing: 0) {
                // Follows the same reading as the slime beside it: an open
                // group is holding nothing, however many icons it owns.
                Text(inventory.held.isEmpty
                     ? "숨긴 아이콘 없음"
                     : inventory.concealed.isEmpty
                       ? "\(inventory.held.count)개 꺼내 둠"
                       : "\(inventory.concealed.count)개 물고 있음")
                    .font(.headline)
                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if engine.hasToggleableGroup {
                Button(anyCollapsed ? "펼치기" : "접기", action: onToggle)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Says what the toggle will do, and says nothing misleading when there is
    /// no toggleable group — "감춰져 있습니다" beside a button that cannot
    /// reveal anything is worse than silence.
    private var statusLine: String {
        guard engine.hasToggleableGroup else { return "항상 숨김만 있습니다" }
        return anyCollapsed ? "지금 감춰져 있습니다" : "지금 펼쳐져 있습니다"
    }

    // MARK: - Groups

    @ViewBuilder
    private func group(title: String, zone: MenuBarZone) -> some View {
        let entries = inventory.items(in: zone)
        if !entries.isEmpty {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)

            ForEach(entries) { item in
                row(item, currentZone: zone)
            }
        }
    }

    private func row(_ item: MenuBarInventory.Item, currentZone: MenuBarZone) -> some View {
        HStack(spacing: 8) {
            appIcon(for: item).frame(width: 17, height: 17)

            Text(item.ownerName)
                .lineLimit(1)
            if inventory.activeIDs.contains(item.id) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(.orange)
                    .help("숨겨진 사이에 이 아이콘이 바뀌었습니다")
            }

            Spacer(minLength: 6)

            if inventory.pendingMove(for: item) != nil {
                Text("대기")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Button("취소") { inventory.cancelMove(for: item) }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            } else if inventory.canMove(item) {
                // Order first, then side. Both write the same stored value,
                // so they carry the same restart caveat — but reordering is
                // the more frequent act once things are where they belong.
                HStack(spacing: 2) {
                    Button {
                        inventory.reorder(item, towardLeft: true)
                    } label: { Image(systemName: "chevron.left") }
                        .help("왼쪽으로")
                    Button {
                        inventory.reorder(item, towardLeft: false)
                    } label: { Image(systemName: "chevron.right") }
                        .help("오른쪽으로")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)

                // One button, and it says where the icon is going. The
                // destination is the other side of the boundary, which is what
                // "put in" and "take out" mean with a single group.
                Button(currentZone == .visible ? "넣기" : "꺼내기") {
                    move(item, from: currentZone)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func appIcon(for item: MenuBarInventory.Item) -> Image {
        if let pid = item.processIdentifier,
           let app = NSRunningApplication(processIdentifier: pid),
           let icon = app.icon {
            return Image(nsImage: icon).resizable()
        }
        return Image(systemName: "app.dashed").resizable()
    }

    // MARK: - Apply

    private var applyStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.orange)
                Text("\(waiting.count)개가 앱 재시작을 기다립니다")
                    .font(.caption)
                Spacer()
                Button("적용") { onRestart(waiting) }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
            // The distinction that decides whether this app is tolerable to
            // live with: a restart buys a *permanent* place for the icon, and
            // hiding it after that is instant. Without saying so the strip
            // reads as "every hide costs a restart", which would be miserable.
            Text("한 번만 하면 됩니다. 자리를 옮기는 것이라, 그 뒤로 감추고 "
                 + "꺼내는 것은 슬라임 클릭만으로 즉시 됩니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.08))
    }

    /// ZipBar's own position. Separated from the icon rows because it is
    /// the one move that applies immediately — we create these items, so we
    /// can make them again — and because it needs no restart to explain.
    private var selfMoveRow: some View {
        HStack(spacing: 8) {
            Text("ZipBar 위치")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onMoveSelf(SelfPlacement.step)
            } label: { Image(systemName: "chevron.left") }
                .disabled(!canMoveSelf(SelfPlacement.step))
                .help("슬라임을 왼쪽으로")
            Button {
                onMoveSelf(-SelfPlacement.step)
            } label: { Image(systemName: "chevron.right") }
                .disabled(!canMoveSelf(-SelfPlacement.step))
                .help("슬라임을 오른쪽으로")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if hasAlwaysHidden {
                // Always-hidden groups do not open on a normal click, which
                // makes their icons unreachable without dismantling the group.
                // This is the deliberate way in.
                Button("항상 숨김까지 보기", action: onRevealAll)
                    .buttonStyle(.link)
                    .font(.caption)
            }
            Spacer()
            Button("설정…", action: onOpenSettings)
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Actions

    private func move(_ item: MenuBarInventory.Item, from zone: MenuBarZone) {
        // Into the first group when coming from outside, back outside when
        // coming from any group — the simple reading of one button.
        let destination: MenuBarZone = zone == .visible ? .group(0) : .visible
        inventory.move(item, toZone: destination)
    }
}
