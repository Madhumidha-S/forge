import Foundation
import ForgeCore

public struct FlutterDetector: ToolDetector {
    public let id: ToolID = .flutter
    public let displayName = "Flutter"

    private let fileManager: FileManager
    private let commandRunner: any CommandRunner

    public init(
        fileManager: FileManager = .default,
        commandRunner: any CommandRunner = ProcessCommandRunner()
    ) {
        self.fileManager = fileManager
        self.commandRunner = commandRunner
    }

    public func detect() async throws -> DetectionResult {
        let path = try await resolvePathWithRetry()
        return try await probeBinaryWithRetry(at: path, source: "PATH")
    }

    /// Resolves the binary path with a single short retry. The first call
    /// occasionally fails under GUI-app launch-time contention — when the
    /// eight detectors fire in parallel inside `withTaskGroup` while the
    /// app is still finishing its own setup, the subprocess that runs
    /// `command -v flutter` can race with sibling processes and miss the
    /// window. A 150 ms retry absorbs that transient without changing the
    /// happy-path latency.
    private func resolvePathWithRetry() async throws -> String {
        do {
            return try resolveViaPath()
        } catch {
            try? await Task.sleep(nanoseconds: 150_000_000)
            return try resolveViaPath()
        }
    }

    /// Probes the binary with a single short retry for the same reason as
    /// `resolvePathWithRetry`: Flutter's first Dart VM cold start can
    /// race with the launch-time scan; the retry reliably succeeds.
    private func probeBinaryWithRetry(at path: String, source: String) async throws -> DetectionResult {
        do {
            return try await probeBinary(at: path, source: "PATH")
        } catch {
            try? await Task.sleep(nanoseconds: 150_000_000)
            return try await probeBinary(at: path, source: "PATH")
        }
    }

    private func resolveViaPath() throws -> String {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-ilc", "command -v flutter"]
        )
        guard result.exitCode == 0 else { throw DetectionError.notFound }
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw DetectionError.notFound }
        return raw
    }

    private func probeBinary(at path: String, source: String) async throws -> DetectionResult {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: path),
            arguments: ["--version"]
        )
        guard result.exitCode == 0 else { throw DetectionError.notFound }
        let firstLine = result.stdout
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let withoutPrefix = firstLine.hasPrefix("Flutter ") ? String(firstLine.dropFirst("Flutter ".count)) : firstLine
        let versionToken = withoutPrefix.split(separator: " ", omittingEmptySubsequences: true).first
        guard let token = versionToken, let semver = SemVer(parsing: String(token)) else {
            throw DetectionError.malformedOutput(detail: "flutter --version output was \(firstLine)")
        }
        return DetectionResult(
            toolId: .flutter,
            version: semver,
            installPath: path,
            healthChecks: [HealthCheck(name: "binary-source", passed: true, detail: source)]
        )
    }
}
