import Foundation
import ForgeCore

/// Runs an executable and returns its stdout. Protocol-based so tests can mock
/// `which`, `node --version`, etc. without spawning real processes.
public protocol CommandRunner: Sendable {
    func run(executable: URL, arguments: [String]) throws -> CommandResult
}

public struct CommandResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

/// Production CommandRunner that shells out via `Process`.
public struct ProcessCommandRunner: CommandRunner {
    public init() {}
    public func run(executable: URL, arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}

public struct NodeDetector: ToolDetector {
    public let id: ToolID = .node
    public let displayName = "Node.js"

    private let fileManager: FileManager
    private let homeDirectory: URL?
    private let commandRunner: any CommandRunner

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = FileManager.default.homeDirectoryForCurrentUser,
        commandRunner: any CommandRunner = ProcessCommandRunner()
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.commandRunner = commandRunner
    }

    public func detect() async throws -> DetectionResult {
        if let path = try? await resolveViaPath() {
            return try await probeBinary(at: path, source: "PATH")
        }
        if let path = try? resolveViaNvm() {
            return try await probeBinary(at: path, source: "nvm")
        }
        throw DetectionError.notFound
    }

    // MARK: - Resolution

    private func resolveViaPath() async throws -> String {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/which"),
            arguments: ["node"]
        )
        guard result.exitCode == 0 else { throw DetectionError.notFound }
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw DetectionError.notFound }
        return raw
    }

    private func resolveViaNvm() throws -> String {
        guard let home = homeDirectory else { throw DetectionError.notFound }
        let nvmRoot = home
            .appendingPathComponent(".nvm")
            .appendingPathComponent("versions")
            .appendingPathComponent("node")
        let contents = (try? fileManager.contentsOfDirectory(
            at: nvmRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let candidate = contents
            .filter { $0.lastPathComponent.hasPrefix("v") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
        guard let pick = candidate else { throw DetectionError.notFound }
        let binary = pick.appendingPathComponent("bin").appendingPathComponent("node")
        guard fileManager.isExecutableFile(atPath: binary.path) else {
            throw DetectionError.notFound
        }
        return binary.path
    }

    private func probeBinary(at path: String, source: String) async throws -> DetectionResult {
        let result = try commandRunner.run(
            executable: URL(fileURLWithPath: path),
            arguments: ["--version"]
        )
        guard result.exitCode == 0 else { throw DetectionError.notFound }
        let raw = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
        guard let semver = SemVer(parsing: stripped) else {
            throw DetectionError.malformedOutput(detail: "node --version output was \(raw)")
        }
        return DetectionResult(
            toolId: .node,
            version: semver,
            installPath: path,
            healthChecks: [HealthCheck(name: "binary-source", passed: true, detail: source)]
        )
    }
}
