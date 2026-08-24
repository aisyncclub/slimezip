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
    @ObservedObject var config: RemoteConfig
    @ObservedObject var starPrompt: StarPrompt

    var onOpenSettings: () -> Void
    var onToggle: () -> Void
    var onRevealAll: () -> Void
    var onRestart: ([MenuBarInventory.Item]) -> Void
    var onMoveSelf: (Double) -> Void
    var canMoveSelf: (Double) -> Bool
    var onUpdate: () -> Void

    /// Excludes always-hidden groups, which are shut by definition — counting
    /// them pinned this to true and left the button stuck on "펼치기".
    private var anyCollapsed: Bool { engine.isToggleableCollapsed }

    private var hasAlwaysHidden: Bool {
        engine.layout.groups.contains { $0.behavior == .alwaysHidden }
    }

    @State private var hoveringCredit = false

    private var promo: PromoBanner { config.promo }

    /// How tall the list wants to be.
    ///
    /// Measured from the parts rather than guessed: a row is a 26pt icon
    /// plus 7pt of padding either side, and a group heading is a caption
    /// with 10pt above and 2pt below. The ceiling keeps the whole popover
    /// under the bar on a 13" screen once the header, the apply strip and
    /// the two footers are stacked on top of it; the floor stops an empty
    /// bar from collapsing the panel into a sliver.
    private var listHeight: CGFloat {
        let rows = CGFloat(inventory.items.count) * 40
        let headings = CGFloat(inventory.boundaries.count + 1) * 28
        // Cut from 470. A full bar's worth of icons no longer fits at once
        // and scrolls instead, which is the trade: the panel stops running
        // most of the way down the screen every time it opens.
        return min(max(rows + headings + 8, 120), 190)
    }

    private var waiting: [MenuBarInventory.Item] {
        inventory.items.filter { inventory.pendingMove(for: $0) != nil }
    }

    /// Moves that a restart can settle, grouped by app — one entry per app,
    /// however many of its icons were moved.
    private var appsToRestart: [(bundle: String, name: String, count: Int)] {
        inventory.appsAwaitingRestart(among: inventory.items)
    }

    /// Moves waiting on something we will not do. macOS draws Wi-Fi, Battery
    /// and the rest through Control Center; the position is written and will
    /// be read when that agent next starts, but quitting the process that
    /// draws half the menu bar is not ours to do.
    private var waitingForLogin: [MenuBarInventory.Item] {
        waiting.filter { inventory.isSystemManaged($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if engine.hasToggleableGroup { revealBar }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(inventory.boundaries.enumerated()), id: \.offset) { index, boundary in
                        group(title: boundary.name, zone: .group(index))
                    }
                    group(title: L("밖에 나와 있는 것"), zone: .visible)
                }
                .padding(.vertical, 4)
            }
            // An explicit height, not a cap. A ScrollView has no ideal
            // height of its own, so inside a size-to-fit hosting controller
            // `maxHeight` alone let it collapse — with 34 icons in the bar
            // the list still rendered 110pt tall and the panel came out at
            // 320. Asking for the content's height instead makes the panel
            // grow with what is in it.
            .frame(height: listHeight)

            if !waiting.isEmpty {
                Divider()
                applyStrip
            }

            Divider()
            utilityRow
            Divider()
            credit
            updateRow
            // Above the sponsored strip: this one is asking for something,
            // and burying it under an advert would read as a second advert.
            if starPrompt.shouldAsk {
                StarPromptView(prompt: starPrompt, stars: config.stars)
            }
            if promo.enabled && !promo.resolvedText.isEmpty {
                PromoBannerView(promo: promo)
            }
        }
        // Widened from 300. At that width the name, the two reorder
        // arrows and the in/out button sat shoulder to shoulder, and the
        // arrows — the most-used control here — were the smallest targets
        // on the panel.
        .frame(width: 400)
        // No refresh here: the app populates boundaries and collapse state
        // together before showing the panel, and re-reading only half of that
        // from the view would put the two out of step.
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            SlimeDecor.Portrait(
                stage: SlimeRenderer.stage(forHiddenCount: inventory.concealed.count),
                height: 32)
            VStack(alignment: .leading, spacing: 0) {
                // Follows the same reading as the slime beside it: an open
                // group is holding nothing, however many icons it owns.
                Text(inventory.held.isEmpty
                     ? L("숨긴 아이콘 없음")
                     : inventory.concealed.isEmpty
                       ? L("%@개 꺼내 둠", "\(inventory.held.count)")
                       : L("%@개 물고 있음", "\(inventory.concealed.count)"))
                    .font(.headline)
                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// The everyday action, given the size it deserves.
    ///
    /// This is the one that costs nothing: the group's separator inflates or
    /// deflates and the icons appear or vanish at once, with no position
    /// rewritten and no app restarted. The per-row 넣기/꺼내기 beside it moves
    /// an icon across the boundary for good, which is a stored-position write
    /// and therefore a restart — a setup step, not a daily one. Sized the
    /// wrong way round, people reached for the expensive button all day.
    private var revealBar: some View {
        VStack(spacing: 4) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: anyCollapsed ? "eye" : "eye.slash")
                    Text(anyCollapsed
                         ? (inventory.concealed.isEmpty
                            ? L("숨긴 것 꺼내 보기")
                            : L("숨긴 %@개 꺼내 보기", "\(inventory.concealed.count)"))
                         : L("다시 감추기"))
                        .fontWeight(.semibold)
                    Text(L("· 재시작 없이"))
                        .font(.caption2)
                        .opacity(0.75)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    /// Says what the toggle will do, and says nothing misleading when there is
    /// no toggleable group — "감춰져 있습니다" beside a button that cannot
    /// reveal anything is worse than silence.
    private var statusLine: String {
        guard engine.hasToggleableGroup else { return L("항상 숨김만 있습니다") }
        return anyCollapsed ? L("지금 감춰져 있습니다") : L("지금 펼쳐져 있습니다")
    }

    // MARK: - Groups

    @ViewBuilder
    private func group(title: String, zone: MenuBarZone) -> some View {
        let entries = inventory.items(in: zone)
        if !entries.isEmpty {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 2)

            ForEach(entries) { item in
                row(item, currentZone: zone)
            }
        }
    }

    private func row(_ item: MenuBarInventory.Item, currentZone: MenuBarZone) -> some View {
        HStack(spacing: 8) {
            appIcon(for: item).frame(width: 26, height: 26)

            Text(item.ownerName)
                .lineLimit(1)
                .font(.system(size: 13))
            if inventory.activeIDs.contains(item.id) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(.orange)
                    .help(L("숨겨진 사이에 이 아이콘이 바뀌었습니다"))
            }

            Spacer(minLength: 6)

            if inventory.pendingMove(for: item) != nil {
                Text(inventory.isSystemManaged(item) ? L("다음 로그인") : L("재시작 대기"))
                    .font(.caption2)
                    .foregroundStyle(inventory.isSystemManaged(item) ? Color.secondary : Color.orange)
                Button(L("취소")) { inventory.cancelMove(for: item) }
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
                        .help(L("왼쪽으로"))
                    Button {
                        inventory.reorder(item, towardLeft: false)
                    } label: { Image(systemName: "chevron.right") }
                        .help(L("오른쪽으로"))
                }
                .buttonStyle(.borderless)
                .controlSize(.regular)

                // One button, and it says where the icon is going. The
                // destination is the other side of the boundary, which is what
                // "put in" and "take out" mean with a single group.
                Button(currentZone == .visible ? L("넣기") : L("꺼내기")) {
                    move(item, from: currentZone)
                }
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 14)
        // 3pt gave a 23pt row — under the 28pt that reads as comfortably
        // clickable, and the rows ran together into one grey block.
        .padding(.vertical, 7)
        .contentShape(Rectangle())
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

    @ViewBuilder
    private var applyStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !appsToRestart.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                    // Counted in apps, because that is what the button does.
                    // Counting icons overstated it: two icons from one app is
                    // one quit, not two.
                    Text(L("%@개 앱을 재시작하면 적용됩니다", "\(appsToRestart.count)"))
                        .font(.caption)
                    Spacer()
                    Button(L("적용")) { onRestart(waiting) }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                }
                Text(appsToRestart.map { $0.count > 1 ? "\($0.name) (\($0.count))" : $0.name }
                        .joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("아이콘마다 한 번뿐입니다."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !waitingForLogin.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("%@개는 다음 로그인에 적용됩니다", "\(waitingForLogin.count)"))
                            .font(.caption)
                        Text(L("제어 센터는 껐다 켜지 않습니다. 자리는 이미 기록해 뒀습니다."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.08))
    }

    /// ZipBar's own position. Separated from the icon rows because it is
    /// the one move that applies immediately — we create these items, so we
    /// can make them again — and because it needs no restart to explain.
    private var utilityRow: some View {
        HStack(spacing: 10) {
            Text(L("위치"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                onMoveSelf(SelfPlacement.step)
            } label: { Image(systemName: "chevron.left") }
                .disabled(!canMoveSelf(SelfPlacement.step))
                .help(L("슬라임을 왼쪽으로"))
            Button {
                onMoveSelf(-SelfPlacement.step)
            } label: { Image(systemName: "chevron.right") }
                .disabled(!canMoveSelf(-SelfPlacement.step))
                .help(L("슬라임을 오른쪽으로"))

            Spacer(minLength: 8)

            if hasAlwaysHidden {
                // Always-hidden groups do not open on a normal click, which
                // makes their icons unreachable without dismantling the
                // group. This is the deliberate way in.
                Button(L("항상 숨김까지"), action: onRevealAll)
                    .buttonStyle(.link)
                    .font(.caption)
            }
            Button(L("설정…"), action: onOpenSettings)
                .buttonStyle(.link)
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    /// Who made this, and where to find them.
    ///
    /// The text and the two marks are separate buttons rather than one strip
    /// with links inside it: a button cannot be nested in a button, and each
    /// of the three goes somewhere different.
    private var credit: some View {
        HStack(spacing: 10) {
            Button { CreatorLinks.open(CreatorLinks.home) } label: {
                HStack(spacing: 5) {
                    Text(L("제작자 Ai싱크클럽"))
                        .fontWeight(.semibold)
                    Text(L("- 싱크 제작"))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .semibold))
                }
                .font(.caption)
                .foregroundStyle(hoveringCredit ? Color.accentColor : Color.secondary)
                // Without this the row is clickable only where the glyphs
                // are, which for a strip of small text is most of it missing.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hoveringCredit = $0 }
            .help(CreatorLinks.home)

            Spacer(minLength: 8)

            MarkButton(mark: .youtube, url: CreatorLinks.youTube, label: L("유튜브"))
            MarkButton(mark: .threads, url: CreatorLinks.threads, label: L("쓰레드"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }



    /// The update line, in whichever of its three states applies.
    ///
    /// A newer version outranks everything: once there is something to
    /// install, the button to look again is beside the point. Otherwise the
    /// row is the button, and it answers in place rather than in a dialog —
    /// a modal that says "최신입니다" and needs dismissing is a punishment for
    /// pressing it.
    @ViewBuilder
    private var updateRow: some View {
        if config.updateAvailable {
            Button { onUpdate() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(L("새 버전 %@이 있습니다", config.latestVersion ?? ""))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 4)
                    Text(L("업데이트"))
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                .modifier(UpdateRowChrome())
            }
            .buttonStyle(.plain)
            .help(L("지금 %1$@ → %2$@", config.currentVersion,
                    config.latestVersion ?? ""))
        } else {
            Button { config.checkNow() } label: {
                HStack(spacing: 8) {
                    Image(systemName: config.isChecking
                          ? "arrow.triangle.2.circlepath"
                          : "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Text(checkLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if !config.isChecking {
                        Text(L("업데이트 확인"))
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .modifier(UpdateRowChrome())
            }
            .buttonStyle(.plain)
            .disabled(config.isChecking)
            .help(RemoteConfig.releasesPage)
        }
    }

    private var checkLabel: String {
        if config.isChecking { return L("확인 중…") }
        if config.lastCheckedAt != nil { return L("최신입니다 · 버전 %@", config.currentVersion) }
        return L("버전 %@", config.currentVersion)
    }

    // MARK: - Actions

    private func move(_ item: MenuBarInventory.Item, from zone: MenuBarZone) {
        // Into the first group when coming from outside, back outside when
        // coming from any group — the simple reading of one button.
        let destination: MenuBarZone = zone == .visible ? .group(0) : .visible
        inventory.move(item, toZone: destination)
    }
}

/// Shared padding for the update row's two faces, so switching between them
/// does not change the panel's height by a pixel.
private struct UpdateRowChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }
}
