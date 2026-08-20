import AppKit

/// Quits another app and starts it again.
///
/// Needed because a status item reads its stored position only when it is
/// created: a running app has already read its own and will not look again, so
/// a rewritten position stays theoretical until that app next launches.
///
/// Kept apart from `MenuBarArranger` on purpose. Writing a preference is
/// reversible and invisible; ending someone's running app is neither. Callers
/// are expected to ask first, by name, every time — this type deliberately
/// offers no way to restart a list of apps in one go.
public struct AppRestarter {

    public enum Outcome: Sendable {
        case restarted
        /// The app refused to quit — an unsaved document, usually. Nothing was
        /// forced, and nothing is broken; the move simply waits.
        case refusedToQuit
        case notRunning
        case failedToRelaunch
    }

    /// How long to wait for the old process to go away. Relaunching too early
    /// just activates the instance that is still dying, and the new position
    /// never gets read.
    static let quitTimeout: TimeInterval = 6
    static let pollInterval: TimeInterval = 0.3

    public init() {}

    @MainActor
    public func isRunning(_ bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Asks the app to quit, waits for it to go, then launches it again.
    ///
    /// Uses `terminate()` rather than `forceTerminate()` so an app with
    /// unsaved work gets to put up its own dialog and refuse. A menu bar
    /// tidier has no business discarding someone's document.
    @MainActor
    public func restart(_ bundleIdentifier: String, completion: @escaping (Outcome) -> Void) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard let app = running.first, let url = app.bundleURL else {
            completion(.notRunning)
            return
        }

        app.terminate()
        waitForExit(bundleIdentifier, deadline: Date().addingTimeInterval(Self.quitTimeout)) { exited in
            guard exited else {
                completion(.refusedToQuit)
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            // A menu bar agent coming back should not steal focus.
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                DispatchQueue.main.async {
                    completion(error == nil ? .restarted : .failedToRelaunch)
                }
            }
        }
    }

    @MainActor
    private func waitForExit(
        _ bundleIdentifier: String,
        deadline: Date,
        completion: @escaping (Bool) -> Void
    ) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
            completion(true)
            return
        }
        guard Date() < deadline else {
            completion(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pollInterval) {
            MainActor.assumeIsolated {
                waitForExit(bundleIdentifier, deadline: deadline, completion: completion)
            }
        }
    }
}
