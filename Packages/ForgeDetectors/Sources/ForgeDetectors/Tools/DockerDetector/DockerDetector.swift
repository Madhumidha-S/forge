import Foundation
import ForgeCore

public struct DockerDetector: ToolDetector {
    public let id: ToolID = .docker
    public let displayName = "Docker"

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
            arguments: ["-ilc", "command -v docker"]
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
        guard tokens.count > 2 else {
            throw DetectionError.malformedOutput(detail: "docker --version output was \(raw)")
        }
        let versionString = String(tokens[2]).trimmingCharacters(in: CharacterSet(charactersIn: ","))
        guard let semver = SemVer(parsing: versionString) else {
            throw DetectionError.malformedOutput(detail: "docker --version output was \(raw)")
        }

        let infoResult = try commandRunner.run(
            executable: URL(fileURLWithPath: path),
            arguments: ["info"]
        )
        let isRunning = infoResult.exitCode == 0
        let runningStatus: RunningStatus = isRunning ? .running : .stopped

        return DetectionResult(
            toolId: .docker,
            version: semver,
            installPath: path,
            runningStatus: runningStatus,
            healthChecks: [
                HealthCheck(name: "binary-source", passed: true, detail: source),
                HealthCheck(name: "daemon-running", passed: isRunning, detail: nil)
            ]
        )
    }
}
