import ApplicationServices
import AppKit
import SwiftUI
import ZipBarKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = MenuBarEngine()
    private let inventory = MenuBarInventory()
    private var controlItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var inventoryTimer: Timer?
    private let animator = SlimeAnimator()
    private var quickPanel: NSPopover?
    private var dismissMonitor: Any?
    /// Current deformation and eye state, driven by the animator.
    private var slimeSquash: CGFloat = 0
    private var slimeBlinking = false

    /// Autosave name for the app's own control item.
    static let controlAutosaveName = "com.zipbar.control"

    /// Asks macOS for Accessibility, which is the only way to learn which
    /// app owns which menu bar icon on macOS 26.
    ///
    /// The system dialog is worth more than the settings pane alone: it
    /// registers the app in the Accessibility list, so the user only has to
    /// flip a toggle. Dragging a bundle into that list by hand is unreliable
    /// on recent macOS, and an app that is not listed cannot be enabled at all.
    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        FileHandle.standardError.write(Data("axTrustedAfterPrompt=\(trusted)\n".utf8))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["ZIPBAR_REQUEST_AX"] == "1" {
            requestAccessibilityIfNeeded()
            NSApp.terminate(nil)
            return
        }

        // Repair and order our stored positions before a single status item
        // exists — once an item is created macOS has already read its saved
        // position, and a poisoned one puts the item off-screen where the
        // user cannot reach it. See StatusItemPlacement for how a profile
        // gets poisoned in the first place.
        prepareItemPlacement()

        engine.start()
        installControlItem()

        // macOS 26 hosts status items out of process, so nothing outside this
        // app can observe whether our items really landed in the bar. This
        // gives verification a way in: ZIPBAR_DIAGNOSTIC=1 prints what we
        // actually created and exits.
        if ProcessInfo.processInfo.environment["ZIPBAR_DIAGNOSTIC"] == "1" {
            emitDiagnostics()
            NSApp.terminate(nil)
            return
        }

        // Knowing which app owns which icon needs Accessibility, and that
        // is the whole point of the app — so ask on launch when we lack it.
        //
        // This must run on a normal LaunchServices start and the app must
        // keep running: macOS attributes the request to the process that
        // makes it, so invoking the executable straight from a shell files it
        // under the terminal instead of ZipBar, and the app never appears in
        // the Accessibility list for the user to enable.
        if !AXIsProcessTrusted() {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        }

        // Collapsed-state verification hook. Collapsing is what inflates the
        // separator, and an inflated separator is what once pushed our own
        // chevron and control item off-screen — so the collapsed state is
        // exactly the one that needs checking from outside the app.
        // ZIPBAR_START_COLLAPSED=1 enters it directly and keeps running.
        if ProcessInfo.processInfo.environment["ZIPBAR_START_COLLAPSED"] == "1" {
            engine.collapseAll()
        }

        // Whether other apps' icons can be moved decides what the settings
        // UI may offer, so it is measured rather than assumed.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_MOVE"] == "1" {
            let (findings, notes) = AXMovementProbe().probe()
            var out = notes
            for f in findings.prefix(40) {
                let pos = f.settable[kAXPositionAttribute] == true ? "쓰기가능" : "읽기전용"
                out.append("  \(pos)  \(f.ownerName) [\(f.title ?? "-")] actions=\(f.actions.joined(separator: ","))")
            }
            FileHandle.standardError.write(Data((out.joined(separator: "\n") + "\n").utf8))
            NSApp.terminate(nil)
            return
        }

        // What the icon list will show, without opening the window.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_INVENTORY"] == "1" {
            let inventory = MenuBarInventory()
            inventory.boundaries = engine.boundaries()
            inventory.refresh()
            var out = ["authorized=\(inventory.isAuthorized)",
                       "숨겨진 \(inventory.hidden.count)개 / 보이는 \(inventory.visible.count)개"]
            out.append("미표시 \(inventory.notDrawn.count)개는 목록에서 제외")
            out.append("-- 경계 --")
            for b in inventory.boundaries {
                out.append("  \(b.name) [\(b.behavior)] pos=\(Int(b.position))")
            }
            out.append("-- 구역별 --")
            for (i, b) in inventory.boundaries.enumerated() {
                let names = inventory.items(in: .group(i)).map(\.ownerName)
                out.append("  \(b.name): \(names.isEmpty ? "(비어 있음)" : names.joined(separator: ", "))")
            }
            out.append("  밖: \(inventory.items(in: .visible).map(\.ownerName).joined(separator: ", "))")
            out.append("-- 옮겨야 할 것 \(inventory.misplaced.count)개 --")
            for m in inventory.misplaced {
                out.append("  \(m.item.ownerName): \(m.instruction)  [key=\(m.item.preferenceKey)]")
            }
            out.append("-- 키 예시 --")
            for i in inventory.items.filter({ !$0.isOurs }).prefix(4) {
                out.append("  \(i.ownerName) → \(i.preferenceKey)")
            }
            out.append("-- 숨겨짐 --")
            for i in inventory.hidden { out.append("  \(i.ownerName) [\(i.title ?? "-")]") }
            out.append("-- 보임 --")
            for i in inventory.visible { out.append("  \(i.ownerName) [\(i.title ?? "-")]") }
            FileHandle.standardError.write(Data((out.joined(separator: "\n") + "\n").utf8))
            NSApp.terminate(nil)
            return
        }

        // Can the app perform the ⌘-drag itself? Tested only against our
        // own separator: a failed experiment on someone else's icon would
        // scatter the user's bar, and ours we can put back.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_DRAG"] == "1" {
            // Status items are not placed at the instant the app launches, so
            // let the run loop settle before reading positions.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.runDragProbe() }
            return
        }

        // What does a status item actually publish? Decides whether an
        // alert on a hidden app is detectable at all.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_ATTRS"] == "1" {
            var out: [String] = []
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(axApp, 0.25)
                var extras: CFTypeRef?
                guard AXUIElementCopyAttributeValue(axApp, kAXExtrasMenuBarAttribute as CFString, &extras) == .success,
                      let extras, CFGetTypeID(extras) == AXUIElementGetTypeID() else { continue }
                var kids: CFTypeRef?
                guard AXUIElementCopyAttributeValue(extras as! AXUIElement, kAXChildrenAttribute as CFString, &kids) == .success,
                      let children = kids as? [AXUIElement], let first = children.first else { continue }
                var names: CFArray?
                AXUIElementCopyAttributeNames(first, &names)
                let list = (names as? [String] ?? []).sorted()
                out.append("\(app.localizedName ?? "?"): \(list.joined(separator: " "))")
            }
            FileHandle.standardError.write(Data((out.joined(separator: "\n\n") + "\n").utf8))
            NSApp.terminate(nil)
            return
        }

        // Renders the motion curves to a filmstrip so the animation can be
        // inspected without watching the menu bar in real time.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_ANIM"] == "1" {
            let out = ProcessInfo.processInfo.environment["ZIPBAR_ANIM_OUT"] ?? "/tmp/slime-anim.png"
            emitFilmstrip(to: out)
            NSApp.terminate(nil)
            return
        }

        // End-to-end check of the move path against a real third-party app,
        // exercising the same code the buttons run. ZIPBAR_PROBE_MOVE_APPLY
        // names the bundle id; the write is applied, verified, then reverted
        // so the probe leaves no trace.
        if let bundle = ProcessInfo.processInfo.environment["ZIPBAR_PROBE_MOVE_APPLY"] {
            var out: [String] = []
            let arranger = MenuBarArranger()
            let boundary = engine.boundaryPosition() ?? -1
            out.append("boundary=\(boundary)")
            if let plan = arranger.plan(
                bundleIdentifier: bundle, ownerName: bundle, indexInApp: 0,
                side: .hidden, boundaryPosition: boundary) {
                out.append("plan: key=\(plan.key) current=\(plan.currentPosition.map { "\($0)" } ?? "nil") target=\(plan.targetPosition)")
                if case .some(let prev) = arranger.apply(plan) {
                    let now = arranger.storedPosition(for: bundle, key: plan.key)
                    out.append("applied: now=\(now.map { "\($0)" } ?? "nil") previous=\(prev.map { "\($0)" } ?? "nil")")
                    arranger.revert(plan, to: prev)
                    let back = arranger.storedPosition(for: bundle, key: plan.key)
                    out.append("reverted: now=\(back.map { "\($0)" } ?? "nil")")
                } else {
                    out.append("적용 실패")
                }
            } else {
                out.append("계획 실패")
            }
            FileHandle.standardError.write(Data((out.joined(separator: "\n") + "\n").utf8))
            NSApp.terminate(nil)
            return
        }

        // Renders the settings views to a file so their appearance can be
        // checked without a screen recording permission or a human at the
        // keyboard. The window itself cannot be opened from a script, and
        // "it compiles" says nothing about whether the slimes draw.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_UI"] == "1" {
            let out = ProcessInfo.processInfo.environment["ZIPBAR_UI_OUT"] ?? "/tmp/zipbar-ui.png"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.renderSettingsPreview(to: out)
                NSApp.terminate(nil)
            }
            return
        }

        // Opens the quick panel directly, to tell a broken popover apart from
        // a click that never reaches the handler.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_PANEL"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.toggleQuickPanel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    let shown = self.quickPanel?.isShown ?? false
                    let windows = NSApp.windows.count
                    FileHandle.standardError.write(Data(
                        "popoverShown=\(shown) windows=\(windows) active=\(NSApp.isActive)\n".utf8))
                    NSApp.terminate(nil)
                }
            }
            return
        }

        // Captures the quick panel exactly as it draws, so a claim about its
        // size or contents can be looked at instead of asserted.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_PANEL_SHOT"] == "1" {
            let out = ProcessInfo.processInfo.environment["ZIPBAR_PANEL_OUT"]
                ?? "/tmp/zipbar-panel.png"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.toggleQuickPanel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.capturePanel(to: out)
                    NSApp.terminate(nil)
                }
            }
            return
        }

        // Opens the settings window and captures it, same reasoning as the
        // panel shot: the tabs are built on ScrollView, which ImageRenderer
        // will not draw. ZIPBAR_SETTINGS_TAB picks the tab.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_SETTINGS_SHOT"] == "1" {
            let out = ProcessInfo.processInfo.environment["ZIPBAR_SETTINGS_OUT"]
                ?? "/tmp/zipbar-settings.png"
            let which = ProcessInfo.processInfo.environment["ZIPBAR_SETTINGS_TAB"] ?? "welcome"
            let tab: SettingsTab = {
                switch which {
                case "icons": return .icons
                case "groups": return .groups
                case "diagnostics": return .diagnostics
                default: return .welcome
                }
            }()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.showSettings(selecting: tab)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    // Long pages have content below the window, and a capture
                    // that only ever shows the top cannot say whether the
                    // bottom draws at all.
                    if ProcessInfo.processInfo.environment["ZIPBAR_SETTINGS_SCROLL"] == "bottom" {
                        self.scrollSettingsToBottom()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.captureWindow(self.settingsWindow, to: out)
                        NSApp.terminate(nil)
                    }
                }
            }
            return
        }

        // Collapses and expands once, reporting the glyph each time — the
        // claim "the slime deflates when you let the icons out" is about the
        // drawing, so only the drawing can confirm it.
        if ProcessInfo.processInfo.environment["ZIPBAR_PROBE_DEFLATE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                var log: [String] = []
                @MainActor func note(_ label: String) {
                    let image = self.controlItem?.button?.image
                    log.append("\(label): concealed=\(self.inventory.concealed.count) "
                        + "held=\(self.inventory.held.count) "
                        + "stage=\(SlimeRenderer.stage(forHiddenCount: self.inventory.concealed.count)) "
                        + "glyph=\(image.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "nil")")
                }
                // Spaced out: each refresh sweeps every running app's AX tree,
                // and chaining them synchronously starves the run loop that
                // has to redraw the glyph in between.
                @MainActor func step(_ index: Int) {
                    switch index {
                    case 0: self.engine.collapseAll(); self.refreshInventory(); note("접힘")
                    case 1: self.engine.expandAll();  self.refreshInventory(); note("펼침")
                    case 2: self.engine.collapseAll(); self.refreshInventory(); note("다시 접힘")
                    default:
                        FileHandle.standardError.write(Data((log.joined(separator: "\n") + "\n").utf8))
                        NSApp.terminate(nil)
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        MainActor.assumeIsolated { step(index + 1) }
                    }
                }
                step(0)
            }
            return
        }
        // Shifts once after a delay and keeps running, so the move can be
        // measured from outside with the accessibility API — the app's own
        // view of its window frame proved unreliable for this.
        if let raw = ProcessInfo.processInfo.environment["ZIPBAR_SHIFT_SELF"],
           let steps = Double(raw) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                MainActor.assumeIsolated {
                    self.moveSelf(by: SelfPlacement.step * steps)
                    FileHandle.standardError.write(Data("shifted \(steps) steps\n".utf8))
                }
            }
        }
        // First run opens on the welcome page. Nothing visible happens when
        // this app is installed — one slime appears at the end of a bar that
        // already had twenty icons — so something has to say what it is.
        if !UserDefaults.standard.bool(forKey: Self.onboardingShownKey) {
            showSettings(selecting: .welcome)
            UserDefaults.standard.set(true, forKey: Self.onboardingShownKey)
        }
    }

    /// Orders our items left to right as [separator, chevron, …, control]
    /// and discards any stored position that lies off every display.
    private func prepareItemPlacement() {
        let names = SpacerStrategy.autosaveNames(for: engine.layout) + [Self.controlAutosaveName]
        let width = StatusItemPlacement.widestScreenWidth()

        let repaired = StatusItemPlacement.sanitize(autosaveNames: names, widestScreenWidth: width)
        let moved = StatusItemPlacement.enforceOrder(leftToRight: names, widestScreenWidth: width)

        if !repaired.isEmpty || !moved.isEmpty {
            placementReport = "repaired=\(repaired.count) moved=\(moved.count)"
        }
    }

    /// Surfaced through the diagnostic report so a repair is observable.
    private var placementReport: String?

    /// Measures whether a synthesised ⌘-drag moves a status item.
    private func runDragProbe() {
        let inventory = MenuBarInventory()
        inventory.refresh()

        func separator() -> MenuBarInventory.Item? {
            inventory.items.first { $0.isOurs && ($0.title ?? "").contains("구분자") }
        }

        var out: [String] = []
        defer {
            FileHandle.standardError.write(Data((out.joined(separator: "\n") + "\n").utf8))
            NSApp.terminate(nil)
        }

        guard let before = separator(), let frame = before.frame else {
            out.append("구분자를 찾지 못했습니다 — 측정 불가")
            out.append("우리 아이템: " + inventory.items.filter(\.isOurs)
                .map { "\($0.title ?? "-")@\($0.frame.map { "\(Int($0.minX))" } ?? "?")" }
                .joined(separator: ", "))
            return
        }

        let start = CGPoint(x: frame.midX, y: frame.midY)
        let target = CGPoint(x: frame.midX - 120, y: frame.midY)
        out.append("드래그 전: x=\(Int(frame.minX)) y=\(Int(frame.minY))")
        out.append("합성: (\(Int(start.x)),\(Int(start.y))) → (\(Int(target.x)),\(Int(target.y)))")

        let posted = DragSynthesizer.commandDrag(from: start, to: target)
        out.append("이벤트 전송=\(posted)")

        // The bar reflows asynchronously; re-read after it settles.
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }

        inventory.refresh()
        guard let after = separator(), let moved = after.frame else {
            out.append("드래그 후 구분자를 찾지 못했습니다")
            return
        }
        let delta = Int(moved.minX - frame.minX)
        out.append("드래그 후: x=\(Int(moved.minX))  (변화 \(delta)pt)")
        out.append(abs(delta) > 4 ? "✅ 합성 드래그로 이동 가능" : "❌ 이동하지 않음")
    }

    private func emitFilmstrip(to path: String) {
        let motions: [(String, SlimeAnimator.Motion)] =
            [("breathe", .breathe), ("jiggle", .jiggle), ("twitch", .twitch)]
        let frames = 14
        let scale: CGFloat = 4          // menu bar glyphs are too small to judge

        guard let probe = SlimeRenderer.image(hiddenCount: 4, hasActivity: false, squash: 0) else {
            FileHandle.standardError.write(Data("아트워크 없음\n".utf8)); return
        }
        let cell = NSSize(width: probe.size.width * scale, height: probe.size.height * scale)
        let sheet = NSImage(size: NSSize(
            width: cell.width * CGFloat(frames),
            height: cell.height * CGFloat(motions.count)))

        sheet.lockFocusFlipped(false)
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        NSRect(origin: .zero, size: sheet.size).fill()
        for (row, entry) in motions.enumerated() {
            for frame in 0..<frames {
                let t = Double(frame) / Double(frames - 1)
                guard let image = SlimeRenderer.image(
                    hiddenCount: 4, hasActivity: false, squash: entry.1.squash(at: t)) else { continue }
                image.draw(in: NSRect(
                    x: CGFloat(frame) * cell.width,
                    // Bottom row first in flipped-false space; reverse so the
                    // strip reads top-to-bottom in the order listed.
                    y: CGFloat(motions.count - 1 - row) * cell.height,
                    width: cell.width, height: cell.height))
            }
        }
        sheet.unlockFocus()

        guard let tiff = sheet.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { FileHandle.standardError.write(Data("렌더 실패\n".utf8)); return }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data(
            "저장: \(path)  (위→아래: \(motions.map(\.0).joined(separator: ", ")))\n".utf8))
    }

    @MainActor
    private func scrollSettingsToBottom() {
        func find(_ v: NSView) -> NSScrollView? {
            if let s = v as? NSScrollView { return s }
            for sub in v.subviews { if let s = find(sub) { return s } }
            return nil
        }
        guard let root = settingsWindow?.contentView, let scroll = find(root) else { return }
        let doc = scroll.documentView?.frame.height ?? 0
        scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, doc - scroll.bounds.height)))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    /// Writes any window's live contents to a PNG.
    ///
    /// Same technique as the panel shot and for the same reason: caching a
    /// real view's display draws the actual hierarchy, ScrollViews included,
    /// offscreen, with no screen recording permission and none of the user's
    /// desktop in frame.
    private func captureWindow(_ window: NSWindow?, to path: String) {
        var lines: [String] = []
        func report(_ line: String) {
            FileHandle.standardError.write(Data((line + "\n").utf8))
            lines.append(line)
        }
        defer { try? lines.joined(separator: "\n").write(
            toFile: path + ".txt", atomically: true, encoding: .utf8) }

        guard let view = window?.contentView else {
            report("windowShot=none 창이 열리지 않았습니다")
            return
        }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            report("windowShot=none 비트맵을 만들지 못했습니다")
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            report("windowShot=none PNG 변환에 실패했습니다")
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
        report("windowShot=\(path) size=\(Int(bounds.width))x\(Int(bounds.height))")

        // The class names of what is actually on screen. A capture that comes
        // out without a tab bar has two explanations — the bar is missing, or
        // cacheDisplay did not draw it — and only the hierarchy tells them
        // apart.
        func walk(_ v: NSView, _ depth: Int) {
            let f = v.frame
            report(String(repeating: "  ", count: depth)
                   + "\(type(of: v)) \(Int(f.minX)),\(Int(f.minY)) "
                   + "\(Int(f.width))x\(Int(f.height))")
            guard depth < 4 else { return }
            for sub in v.subviews { walk(sub, depth + 1) }
        }
        walk(view, 0)
    }

    /// Writes the quick panel to a PNG, drawn by AppKit rather than described.
    ///
    /// `ImageRenderer` is no help here — it substitutes a "not supported"
    /// placeholder for the ScrollView the panel is built around, which is
    /// exactly the part worth looking at. Caching the live view's display
    /// draws the real hierarchy instead: offscreen, needing no screen
    /// recording permission, and with none of the user's desktop in frame.
    private func capturePanel(to path: String) {
        // Also to a file beside the image: launching through LaunchServices
        // is what gives the app its own accessibility grant, and that is the
        // one way of starting it that does not hand stderr back to a shell.
        var lines: [String] = []
        func report(_ line: String) {
            FileHandle.standardError.write(Data((line + "\n").utf8))
            lines.append(line)
        }
        defer { try? lines.joined(separator: "\n").write(
            toFile: path + ".txt", atomically: true, encoding: .utf8) }
        guard let view = quickPanel?.contentViewController?.view else {
            report("panelShot=none 패널이 열리지 않았습니다")
            return
        }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            report("panelShot=none 비트맵을 만들지 못했습니다")
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            report("panelShot=none PNG 변환에 실패했습니다")
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
        report("panelShot=\(path) size=\(Int(bounds.width))x\(Int(bounds.height)) "
               + "rows=\(inventory.items.count)")

        // Where the popover actually landed, against the screen it landed on.
        // "It looks like it goes off the edge" is a claim about coordinates,
        // so print the coordinates rather than eyeball the picture.
        if let window = view.window, let screen = window.screen ?? NSScreen.main {
            let w = window.frame, v = screen.visibleFrame
            report("panelFrame=\(Int(w.minX)),\(Int(w.minY)) \(Int(w.width))x\(Int(w.height)) "
                   + "screen=\(Int(v.minX)),\(Int(v.minY)) \(Int(v.width))x\(Int(v.height)) "
                   + "overflowRight=\(Int(max(0, w.maxX - v.maxX))) "
                   + "overflowLeft=\(Int(max(0, v.minX - w.minX))) "
                   + "overflowBottom=\(Int(max(0, v.minY - w.minY)))")
        }
    }

    private func renderSettingsPreview(to path: String) {
        refreshInventory()

        // ImageRenderer cannot draw List or ScrollView — it substitutes a
        // "not supported" placeholder — so the preview composes the pieces
        // those containers would hold. That is what needs checking anyway:
        // whether the slimes draw at the right size and proportion.
        let preview = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(inventory.boundaries.enumerated()), id: \.offset) { index, boundary in
                ZoneHeader(
                    title: boundary.name,
                    subtitle: boundary.behavior == .alwaysHidden
                        ? "슬라임이 계속 물고 있습니다"
                        : "슬라임을 누르면 여기가 열리고 닫힙니다",
                    count: self.inventory.items(in: .group(index)).count)
            }
            ZoneHeader(
                title: "밖에 나와 있는 것", subtitle: "언제나 메뉴바에 보입니다",
                count: self.inventory.items(in: .visible).count)

            Divider()
            SlimeEmptyState(message: "여기는 아직 비어 있습니다. 아래에서 넣어보세요.")

            Divider()
            Text("단계별 (설정 화면 크기)").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                ForEach(1...SlimeRenderer.stageCount, id: \.self) { stage in
                    VStack(spacing: 3) {
                        SlimeDecor.Portrait(stage: stage, height: 30, animated: false)
                        Text("\(stage)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            Text("사용법 항목").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                SlimeDecor.Portrait(stage: 1, height: 26, animated: false)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text("메뉴바의 슬라임이 SlimeZIP입니다").font(.headline)
                    Text("숨긴 아이콘이 없으면 한 마리가 둥글게 쉬고 있습니다.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(width: 620, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: preview)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("렌더 실패\n".utf8)); return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("저장: \(path)\n".utf8))
    }

    /// Report what actually reached the menu bar.
    private func emitDiagnostics() {
        var lines = [
            "backend=\(engine.capabilities.backend.rawValue)",
            "groups=\(engine.layout.groups.count)",
            "controlItem=\(controlItem?.button != nil ? "ok" : "missing")",
            "controlItemVisible=\(controlItem?.isVisible ?? false)",
            "placement=\(placementReport ?? "unchanged")",
        ]
        for group in engine.layout.groups {
            let collapsed = engine.collapseState[group.id] ?? false
            lines.append("group '\(group.name)' id=\(group.id.uuidString.prefix(8)) collapsed=\(collapsed)")
        }
        // Status items are not enumerable from outside, but NSStatusBar
        // reports the thickness it is managing for us.
        lines.append("menuBarThickness=\(NSStatusBar.system.thickness)")
        // The slime is the app's only icon; if its artwork is missing the
        // user sees nothing, so the diagnostic says whether it loaded.
        lines.append("slimeArtwork=\(SlimeRenderer.availableStageCount)/\(SlimeRenderer.stageCount)")
        // What the button is actually showing, which is the only thing the
        // user sees. Artwork existing on disk does not prove it was applied.
        if let button = controlItem?.button {
            let size = button.image.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "nil"
            lines.append("buttonImage=\(size) title='\(button.title)' template=\(button.image?.isTemplate ?? false)")
        }
        lines.append("hiddenCountAtInstall=\(inventory.hidden.count)")

        // Whether we can see other apps' icons at all decides what the app
        // can offer: without identity there is no list to show and nothing to
        // move in or out, only the blind ⌘-drag the OS already provides. Run
        // this from inside the bundle so the Accessibility grant applies.
        lines.append("axTrusted=\(AXIsProcessTrusted())")
        let sweep = AXSweepProbe().probe()
        lines.append("axItems=\(sweep.items.count)")
        for note in sweep.notes { lines.append("  note: \(note)") }
        for item in sweep.items.prefix(40) {
            lines.append("  · \(item.ownerName ?? "?") [\(item.bundleIdentifier ?? "-")] "
                + "title=\(item.title ?? "-") frame=\(item.frame.map { "\(Int($0.origin.x)),\(Int($0.width))" } ?? "-")")
        }
        FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    func applicationWillTerminate(_ notification: Notification) {
        animator.stop()
        inventoryTimer?.invalidate()
        engine.stop()
    }

    private static let onboardingShownKey = "com.zipbar.onboardingShown"

    // MARK: - Control item

    /// The app's own home in the menu bar: opens settings, expands or
    /// collapses everything, quits.
    private func installControlItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.controlAutosaveName

        // The slime is ZipBar's only icon, so one button carries both jobs:
        // a left click opens and shuts the group, a right click reaches the
        // menu. Assigning `item.menu` would make the left click open the menu
        // too and cost the app its one-click toggle.
        item.button?.target = self
        item.button?.action = #selector(slimeClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        controlItem = item

        animator.onFrame = { [weak self] squash, blinking in
            guard let self else { return }
            self.slimeSquash = squash
            self.slimeBlinking = blinking
            self.refreshSlime()
        }
        animator.startIdling()
        refreshSlime()

        // The slime's shape is a reading of the bar, which changes without
        // us: the user can ⌘-drag an icon across the boundary at any time.
        inventoryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshInventory() }
        }
        refreshInventory()
    }

    private func refreshInventory() {
        let hadActivity = inventory.hasActivity
        // Boundaries first: the sweep classifies every icon against them, so
        // refreshing with a stale set would file icons under the wrong group.
        let boundaries = engine.boundaries()
        inventory.boundaries = boundaries
        // Which groups are shut decides what the slime is holding *now*, as
        // opposed to what its groups own. Set here, in the one place the
        // inventory is refreshed, so the two can never disagree.
        inventory.collapsedGroups = Set(
            boundaries.enumerated()
                .filter { engine.collapseState[$0.element.groupID] == true }
                .map(\.offset))
        inventory.refresh()
        // A hidden icon changed while the user was not looking: the slime
        // notices before the dot appears, which is what makes the dot feel
        // like the creature reacting rather than a badge being stamped on.
        if inventory.hasActivity && !hadActivity {
            animator.play(.twitch)
        }
        refreshSlime()
    }

    /// Redraws the slime for the current load, falling back to a symbol if the
    /// artwork is ever missing — an empty status item is indistinguishable
    /// from the app having failed to launch.
    private func refreshSlime() {
        guard let button = controlItem?.button else { return }
        // What the slime is holding *now*, not what its groups own. Letting the
        // icons out should visibly deflate it — that is the whole point of the
        // click.
        let hidden = inventory.concealed.count

        if let image = SlimeRenderer.image(
            hiddenCount: hidden,
            hasActivity: inventory.hasActivity,
            squash: slimeSquash,
            blinking: slimeBlinking
        ) {
            button.image = image
            button.title = ""
        } else {
            StatusItemGlyph.apply(
                to: button, symbolName: "rectangle.compress.vertical",
                fallbackText: "SZ", accessibilityDescription: "SlimeZIP")
        }

        let collapsed = engine.layout.groups.contains { engine.collapseState[$0.id] == true }
        let owned = inventory.held.count
        button.toolTip = hidden == 0
            ? (owned == 0 ? "SlimeZIP — 숨겨진 아이콘 없음" : "SlimeZIP — \(owned)개 꺼내 둠")
            : "SlimeZIP — \(hidden)개 숨김\(inventory.hasActivity ? " · 변화 있음" : "")"
        button.setAccessibilityLabel("SlimeZIP, \(hidden)개 숨김, \(collapsed ? "접힘" : "펼침")")
    }

    @objc private func slimeClicked() {
        // No current event means the click came through accessibility
        // (VoiceOver, or automation): treat it as the primary action, which
        // for those callers is the toggle rather than a popover they cannot
        // easily read.
        guard let event = NSApp.currentEvent else {
            toggleAll()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showControlMenu()
        } else if event.modifierFlags.contains(.option) {
            // Power-user shortcut past the panel, for when all you want is to
            // peek and put it back.
            toggleAll()
        } else {
            toggleQuickPanel()
        }
    }

    /// Opens the panel that lets icons be put in and taken out on the spot.
    ///
    /// A plain click used to only collapse and expand, which answered "let me
    /// peek" but not "let me change what is in there" — that meant opening
    /// settings, finding the row, clicking again. Choosing what to hide is the
    /// app's entire purpose, so it belongs one click from the bar.
    private func toggleQuickPanel() {
        guard let button = controlItem?.button else { return }
        if let panel = quickPanel, panel.isShown {
            panel.performClose(nil)
            return
        }

        refreshInventory()
        let content = QuickPanelView(
            inventory: inventory,
            engine: engine,
            onOpenSettings: { [weak self] in
                self?.quickPanel?.performClose(nil)
                self?.showSettings(selecting: .icons)
            },
            onToggle: { [weak self] in self?.toggleAll() },
            onRevealAll: { [weak self] in
                guard let self else { return }
                self.engine.revealAll()
                self.inventory.clearActivity()
                self.animator.play(.jiggle)
                self.refreshInventory()
            },
            onRestart: { [weak self] items in
                self?.quickPanel?.performClose(nil)
                self?.restartSequentially(items)
            },
            onMoveSelf: { [weak self] delta in self?.moveSelf(by: delta) },
            canMoveSelf: { [weak self] delta in self?.canMoveSelf(by: delta) ?? false })

        let popover = NSPopover()
        // Not `.transient`. That behaviour closes the popover on the next
        // click anywhere — including, for an accessory app, the very
        // mouse-up that opened it, so the panel appeared and vanished in the
        // same gesture. Closing is handled below instead, on a click that
        // actually lands outside.
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: content)

        // Activate first: an accessory app is never active on its own, and a
        // popover belonging to an inactive app cannot take keyboard input.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        constrainPanelToScreen()
        // Again after the run loop turns: the popover finishes sizing itself
        // asynchronously, and a correction applied to a stale frame is no
        // correction at all.
        DispatchQueue.main.async { [weak self] in self?.constrainPanelToScreen() }
        quickPanel = popover
        watchForDismissal()

    }

    /// Keeps the panel inside the display it opened on.
    ///
    /// The popover centres itself on the status item, and the item sits close
    /// to the right edge by design — it is ours, so it goes last. Measured at
    /// the current position, a 426pt panel's right edge lands 3pt inside a
    /// 1920pt screen; one nudge further right and half of it is gone. Three
    /// displays make it likelier still.
    ///
    /// Corrected after the fact rather than by pre-offsetting the anchor.
    /// AppKit may already have nudged the popover on its own, and there is no
    /// way to ask whether it did — measuring where the window actually landed
    /// cannot double-count a shift that was already applied.
    private func constrainPanelToScreen() {
        guard let window = quickPanel?.contentViewController?.view.window,
              let screen = window.screen ?? NSScreen.main else { return }
        let margin: CGFloat = 8
        let visible = screen.visibleFrame
        let frame = window.frame
        var origin = frame.origin
        origin.x = min(origin.x, visible.maxX - frame.width - margin)
        origin.x = max(origin.x, visible.minX + margin)
        origin.y = max(origin.y, visible.minY + margin)
        guard origin != frame.origin else { return }
        window.setFrameOrigin(origin)
    }

    /// Closes the panel when the user clicks away from it.
    ///
    /// Replaces what `.transient` would have done, minus its habit of
    /// counting the opening click itself as a dismissal.
    private func watchForDismissal() {
        dismissMonitor.map(NSEvent.removeMonitor)
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.quickPanel, panel.isShown else { return }
                panel.performClose(nil)
                self.dismissMonitor.map(NSEvent.removeMonitor)
                self.dismissMonitor = nil
            }
        }
    }

    /// Restarts apps one at a time. Sequential on purpose: quitting half the
    /// menu bar at once turns the bar into a slot machine, and a single
    /// failure is easier to attribute when they go down one by one.
    private func restartSequentially(_ items: [MenuBarInventory.Item]) {
        // Collapsed to one entry per app before anything is quit. The list
        // arrives as icons, and an app with two of them used to be restarted
        // twice for one trip through the panel.
        restartApps(inventory.appsAwaitingRestart(among: items).map(\.bundle))
    }

    /// One app at a time. Quitting half the menu bar at once turns the bar
    /// into a slot machine, and a single failure is easier to attribute when
    /// they go down one by one.
    private func restartApps(_ bundles: [String]) {
        guard let bundle = bundles.first else {
            refreshInventory()
            return
        }
        inventory.restartApp(bundle) { [weak self] _ in
            self?.restartApps(Array(bundles.dropFirst()))
        }
    }

    /// Slides ZipBar itself along the bar.
    ///
    /// Ours are the only items we can reposition without waiting for an app
    /// to restart, because we are the app that creates them: shift the
    /// stored positions, then build them again.
    ///
    /// - Parameter delta: positive moves left, negative moves right.
    func moveSelf(by delta: Double) {
        guard let plan = engine.plannedOwnPositions(
            by: delta, controlName: Self.controlAutosaveName) else { return }

        let collapsed = engine.collapsedGroupIDs

        // Order matters and cost us a measurement to learn: removing a status
        // item makes macOS clear its stored position, so writing first and
        // removing second erases the write. Tear everything down, then write,
        // then build — the same gap the pending-move flow uses when it has to
        // survive another app quitting.
        if let item = controlItem {
            NSStatusBar.system.removeStatusItem(item)
            controlItem = nil
        }
        engine.teardownItems()
        engine.applyOwnPositions(plan)
        engine.buildItems(restoringCollapsed: collapsed)
        installControlItem()

        refreshInventory()
        animator.play(.jiggle)
    }

    func canMoveSelf(by delta: Double) -> Bool {
        engine.canShiftOwnItems(by: delta, controlName: Self.controlAutosaveName)
    }

    /// Attaches the menu only for the duration of the click, so the left
    /// click keeps its own meaning.
    private func showControlMenu() {
        guard let item = controlItem else { return }
        item.menu = buildMenu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func toggleAll() {
        if engine.isToggleableCollapsed {
            engine.expandAll()
            // The user is looking at the icons now, so whatever changed while
            // they were hidden has been seen.
            inventory.clearActivity()
        } else {
            engine.collapseAll()
        }
        // Swallowing or letting go of icons is the one moment the slime
        // visibly changes size, so it gets the biggest reaction.
        animator.play(.jiggle)
        refreshInventory()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let expand = NSMenuItem(title: "모두 펴기", action: #selector(expandAll), keyEquivalent: "e")
        expand.target = self
        menu.addItem(expand)

        let collapse = NSMenuItem(title: "모두 접기", action: #selector(collapseAll), keyEquivalent: "h")
        collapse.target = self
        menu.addItem(collapse)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "SlimeZIP 종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    /// Surfaces the active backend right in the menu. When a macOS update
    /// takes a mechanism away, the user can see that immediately instead of
    /// concluding the app is broken.
    private func statusLine() -> String {
        switch engine.capabilities.backend {
        case .spacer: return "백엔드: 스페이서 (권한 불필요)"
        case .menuServiceBridge: return "백엔드: 브릿지"
        case .degraded: return "⚠️ 현재 macOS에서 지원 준비 중"
        }
    }

    // MARK: - Actions

    @objc private func expandAll() { engine.expandAll() }
    @objc private func collapseAll() { engine.collapseAll() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func openSettings() { showSettings(selecting: .icons) }

    private func showSettings(selecting tab: SettingsTab) {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            engine.setBoundaryVisible(true)
            return
        }

        let root = SettingsView(engine: engine, initialTab: tab)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SlimeZIP 설정"
        window.contentViewController = NSHostingController(rootView: root)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window

        // Settings open means the user is arranging, which is the only time
        // the drag boundary is worth the second visible item.
        engine.setBoundaryVisible(true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Drop the reference so the next open rebuilds a fresh SwiftUI tree
        // against current engine state.
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
            engine.setBoundaryVisible(false)
        }
    }
}
