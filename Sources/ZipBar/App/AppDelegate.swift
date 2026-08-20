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
    /// Current deformation, driven by the animator between redraws.
    private var slimeSquash: CGFloat = 0

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
            inventory.refresh()
            var out = ["authorized=\(inventory.isAuthorized)",
                       "숨겨진 \(inventory.hidden.count)개 / 보이는 \(inventory.visible.count)개"]
            out.append("미표시 \(inventory.notDrawn.count)개는 목록에서 제외")
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

        // First run: explain the ⌘-drag step, because with the spacer backend
        // nothing appears to happen until the user arranges their icons.
        if !UserDefaults.standard.bool(forKey: Self.onboardingShownKey) {
            showSettings(selecting: .onboarding)
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
        item.autosaveName = "com.zipbar.control"
        StatusItemGlyph.apply(
            to: item.button,
            symbolName: "rectangle.compress.vertical",
            fallbackText: "ZB",
            accessibilityDescription: "ZipBar"
        )
        item.menu = buildMenu()
        controlItem = item
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

        let quit = NSMenuItem(title: "ZipBar 종료", action: #selector(quit), keyEquivalent: "q")
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
            return
        }

        let root = SettingsView(engine: engine, initialTab: tab)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ZipBar 설정"
        window.contentViewController = NSHostingController(rootView: root)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Drop the reference so the next open rebuilds a fresh SwiftUI tree
        // against current engine state.
        if (notification.object as? NSWindow) === settingsWindow {
            settingsWindow = nil
        }
    }
}
