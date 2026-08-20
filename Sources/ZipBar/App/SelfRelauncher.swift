import AppKit

/// Relaunches ZipBar.
///
/// Exists for one dead end: an Accessibility grant given while the app is
/// running. macOS does not reliably extend a new grant to an already-running
/// process — a fresh process sees `AXIsProcessTrusted() == true` while the
/// old one keeps reading false forever. No amount of re-checking inside the
/// stale process can fix that; only a relaunch puts the app on the right
/// side of the grant.
enum SelfRelauncher {
    @MainActor
    static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        // -n forces a new instance even though this one has not fully exited
        // yet; without it, open just activates the dying process and the
        // relaunch silently becomes a no-op.
        process.arguments = ["-n", bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }
}

/// Build marker: real code (not a comment) so that touching it changes the
/// compiled binary — a comment-only edit compiles byte-identically and can't
/// exercise a rebuild.
enum BuildMarker { static let revision = 2 }
