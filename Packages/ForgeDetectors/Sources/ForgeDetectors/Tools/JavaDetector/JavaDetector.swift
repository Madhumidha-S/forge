import Foundation
import ForgeCore

public struct JavaDetector: ToolDetector {
    public let id: ToolID = .java
    public let displayName = "Java"

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
        let path = try resolveHomePath()
        let version = try await probeVersion()
        return DetectionResult(
            toolId: .java,
            version: version,
            installPath: path,
            healthChecks: [HealthCheck(name: "binary-source", passed: true, detail: "java_home")]
        )
    }

    private func resolveHomePath() throws -> String {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/libexec/java_home"),
            arguments: []
        )
        guard result.exitCode == 0 else { throw DetectionError.notFound }
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw DetectionError.notFound }
        return raw
    }

    private func probeVersion() async throws -> SemVer {
        // /usr/libexec/java_home --version requires an argument on this system,
        // so we resolve the JAVA_HOME path first and then invoke the actual
        // java binary's `-version` flag. Java writes the version line to
        // stderr in the form: openjdk version "X.Y.Z".
        let home = try resolveHomePath()
        let javaBin = (home as NSString).appendingPathComponent("bin/java")
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: javaBin),
            arguments: ["-version"]
        )
        let combined = (result.stderr + result.stdout)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let openQuote = combined.firstIndex(of: "\""),
           let closeQuote = combined[combined.index(after: openQuote)...].firstIndex(of: "\"") {
            let candidate = String(combined[combined.index(after: openQuote)..<closeQuote])
            if let semver = SemVer(parsing: candidate) {
                return semver
            }
        }
        throw DetectionError.malformedOutput(detail: "java -version output was \(combined)")
    }
}
