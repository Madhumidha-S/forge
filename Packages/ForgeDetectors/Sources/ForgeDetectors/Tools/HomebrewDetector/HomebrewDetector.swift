import Foundation
import ForgeCore

public struct HomebrewDetector: ToolDetector {
    public let id: ToolID = .homebrew
    public let displayName = "Homebrew"

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
        let (path, source) = try resolvePath()
        return try await probeBinary(at: path, source: source)
    }

    private func resolvePath() throws -> (path: String, source: String) {
        let appleSilicon = "/opt/homebrew/bin/brew"
        let intel = "/usr/local/bin/brew"

        if fileManager.isExecutableFile(atPath: appleSilicon) {
            return (appleSilicon, "apple-silicon")
        }
        if fileManager.isExecutableFile(atPath: intel) {
            return (intel, "intel")
        }
        throw DetectionError.notFound
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
        let stripped = firstLine.hasPrefix("Homebrew ") ? String(firstLine.dropFirst("Homebrew ".count)) : firstLine
        guard let semver = SemVer(parsing: stripped) else {
            throw DetectionError.malformedOutput(detail: "brew --version output was \(firstLine)")
        }
        return DetectionResult(
            toolId: .homebrew,
            version: semver,
            installPath: path,
            healthChecks: [HealthCheck(name: "binary-source", passed: true, detail: source)]
        )
    }
}
