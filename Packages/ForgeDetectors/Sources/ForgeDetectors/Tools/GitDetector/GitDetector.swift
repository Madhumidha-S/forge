import Foundation
import ForgeCore

public struct GitDetector: ToolDetector {
    public let id: ToolID = .git
    public let displayName = "Git"

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
            executable: URL(fileURLWithPath: "/usr/bin/which"),
            arguments: ["git"]
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
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = raw.split(separator: " ", omittingEmptySubsequences: true)
        guard let versionToken = tokens.last, let semver = SemVer(parsing: String(versionToken)) else {
            throw DetectionError.malformedOutput(detail: "git --version output was \(raw)")
        }
        return DetectionResult(
            toolId: .git,
            version: semver,
            installPath: path,
            healthChecks: [HealthCheck(name: "binary-source", passed: true, detail: source)]
        )
    }
}
