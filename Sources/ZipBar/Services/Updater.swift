import Foundation
import AppKit

/// Replaces the running app with the newest release.
///
/// The app does the downloading and unpacking itself rather than piping a
/// remote script into a shell. `curl … | bash` would have been three lines,
/// but it means whatever that URL serves at that moment runs with the user's
/// privileges — a bad trade for a menu bar utility, and one nobody can audit
/// after the fact. Here the only shell is a fixed snippet written below, and
/// the only thing fetched is a zip that must contain a bundle with our own
/// identifier before anything is moved.
///
/// The swap itself has to outlive us: a running app cannot replace its own
/// bundle. So the last act is to hand a detached `/bin/sh` the two paths and
/// quit; it waits for the process to go, moves the new bundle into place and
/// launches it.
@MainActor
struct Updater {

    enum Failure: LocalizedError {
        case noRelease
        case download
        case badArchive
        case notOurApp
        case install(String)

        var errorDescription: String? {
            switch self {
            case .noRelease: return "받을 수 있는 릴리스를 찾지 못했습니다."
            case .download: return "내려받는 중 문제가 생겼습니다. 잠시 뒤 다시 시도해 주세요."
            case .badArchive: return "받은 파일을 열지 못했습니다."
            case .notOurApp: return "받은 파일이 SlimeZIP이 아닙니다. 설치를 중단했습니다."
            case .install(let why): return "설치하지 못했습니다 — \(why)"
            }
        }
    }

    /// Where this copy is installed. The swap targets this, not a guessed
    /// /Applications path: someone running it from Downloads should have that
    /// copy updated, not a second one appear somewhere else.
    static var installedURL: URL { Bundle.main.bundleURL }

    static func downloadAndInstall(
        progress: @escaping (String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        progress("최신 릴리스 확인 중…")
        fetchAssetURL { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let asset):
                progress("내려받는 중…")
                download(asset) { downloaded in
                    switch downloaded {
                    case .failure(let error): completion(.failure(error))
                    case .success(let zip):
                        progress("설치 중…")
                        do {
                            let app = try unpack(zip)
                            try handOff(newBundle: app)
                            completion(.success(()))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Steps

    private static func fetchAssetURL(_ done: @escaping (Result<URL, Error>) -> Void) {
        guard let api = URL(string: RemoteConfig.releasesAPI) else {
            done(.failure(Failure.noRelease)); return
        }
        var request = URLRequest(url: api)
        request.timeoutInterval = 15
        URLSession(configuration: .ephemeral).dataTask(with: request) { data, _, _ in
            struct Payload: Decodable {
                struct Asset: Decodable { let browser_download_url: String }
                let assets: [Asset]
            }
            guard let data,
                  let payload = try? JSONDecoder().decode(Payload.self, from: data),
                  let zip = payload.assets.first(where: { $0.browser_download_url.hasSuffix(".zip") }),
                  let url = URL(string: zip.browser_download_url)
            else {
                Task { @MainActor in done(.failure(Failure.noRelease)) }
                return
            }
            Task { @MainActor in done(.success(url)) }
        }.resume()
    }

    private static func download(_ url: URL, _ done: @escaping (Result<URL, Error>) -> Void) {
        URLSession(configuration: .ephemeral).downloadTask(with: url) { temp, response, _ in
            guard let temp,
                  let http = response as? HTTPURLResponse, http.statusCode == 200
            else {
                Task { @MainActor in done(.failure(Failure.download)) }
                return
            }
            // The task's temp file is deleted the moment this handler returns,
            // so it gets moved somewhere of our own first.
            let kept = FileManager.default.temporaryDirectory
                .appendingPathComponent("slimezip-update-\(UUID().uuidString).zip")
            do {
                try FileManager.default.moveItem(at: temp, to: kept)
                Task { @MainActor in done(.success(kept)) }
            } catch {
                Task { @MainActor in done(.failure(Failure.download)) }
            }
        }.resume()
    }

    private static func unpack(_ zip: URL) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("slimezip-unpack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // ditto rather than NSFileManager: the archive is made with ditto and
        // carries the bundle's symlinks and signature, which a naive unzip
        // flattens.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        task.arguments = ["-x", "-k", zip.path, dir.path]
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw Failure.badArchive }

        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        guard let app = candidates.first(where: {
            $0.pathExtension == "app" && !$0.lastPathComponent.hasPrefix("__")
        }) else { throw Failure.badArchive }

        // Refuse anything that is not us. The archive comes off the network,
        // and "unpack whatever arrived and move it into /Applications" is how
        // an update channel becomes an install channel for something else.
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier
        else { throw Failure.notOurApp }

        return app
    }

    /// Quits, swaps, relaunches — in a process that survives us.
    private static func handOff(newBundle: URL) throws {
        let target = installedURL
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path)
        else { throw Failure.install("\(target.deletingLastPathComponent().path)에 쓸 권한이 없습니다") }

        let pid = ProcessInfo.processInfo.processIdentifier
        // Waits for this exact process rather than sleeping a fixed time: a
        // slow quit would otherwise have the bundle replaced underneath a
        // still-running app.
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        /bin/rm -rf '\(target.path)'
        /usr/bin/ditto '\(newBundle.path)' '\(target.path)'
        /usr/bin/xattr -dr com.apple.quarantine '\(target.path)' 2>/dev/null
        /usr/bin/open '\(target.path)'
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        try task.run()

        NSApp.terminate(nil)
    }
}
