import Foundation
import ForgeCore

public struct PythonDetector: ToolDetector {
    public let id: ToolID = .python
    public let displayName = "Python"

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
            arguments: ["python3"]
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
        let stripped = raw.hasPrefix("Python ") ? String(raw.dropFirst("Python ".count)) : raw
        guard let semver = SemVer(parsing: stripped) else {
            throw DetectionError.malformedOutput(detail: "python3 --version output was \(raw)")
        }
        return DetectionResult(
            toolId: .python,
            version: semver,
            installPath: path,
            healthChecks: [HealthCheck(name: "binary-source", passed: true, detail: source)]
        )
    }
}
