import ApplicationServices
import AppKit
import SwiftUI
import ZipBarKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = MenuBarEngine()
    private var controlItem: NSStatusItem?
    private var settingsWindow: NSWindow?

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
    @objc private func openSettings() { showSettings(selecting: .groups) }

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
