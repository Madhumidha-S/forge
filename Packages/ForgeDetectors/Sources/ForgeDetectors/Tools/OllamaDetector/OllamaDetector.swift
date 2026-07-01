import Foundation
import ForgeCore

public struct OllamaDetector: ToolDetector {
    public let id: ToolID = .ollama
    public let displayName = "Ollama"

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
        let path = try resolveViaPath()
        return try await probeBinary(at: path, source: "PATH")
    }

    private func resolveViaPath() throws -> String {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: "/bin/zsh"),
            arguments: ["-ilc", "command -v ollama"]
        )
        guard result.exitCode == 0 else { throw DetectionError.notFound }
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw DetectionError.notFound }
        return raw
    }

    private func probeBinary(at path: String, source: String) async throws -> DetectionResult {
        let versionResult = try commandRunner.run(
            executable: URL(fileURLWithPath: path),
            arguments: ["--version"]
        )
        guard versionResult.exitCode == 0 else { throw DetectionError.notFound }
        let raw = versionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = raw.split(separator: " ", omittingEmptySubsequences: true)
        guard let semver = tokens.lazy.compactMap({ SemVer(parsing: String($0)) }).first else {
            throw DetectionError.malformedOutput(detail: "ollama --version output was \(raw)")
        }

        let processResult = try commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-x", "ollama"]
        )
        let isRunning = processResult.exitCode == 0
        let runningStatus: RunningStatus = isRunning ? .running : .stopped

        return DetectionResult(
            toolId: .ollama,
            version: semver,
            installPath: path,
            runningStatus: runningStatus,
            healthChecks: [
                HealthCheck(name: "binary-source", passed: true, detail: source),
                HealthCheck(name: "process-running", passed: isRunning, detail: nil)
            ]
        )
    }
}
