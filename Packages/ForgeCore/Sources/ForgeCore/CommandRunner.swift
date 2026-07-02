import Foundation

/// Abstraction over spawning a subprocess and capturing its stdout, stderr,
/// and exit code. Protocol-based so tests can mock `which`, `--version`,
/// etc. without spawning real processes.
///
/// Lives in `ForgeCore` (not `ForgeDetectors`) so the diagnostics engine in
/// `ForgeDiagnostics` can pass a `CommandRunner` to per-tool diagnostics
/// providers without taking a dependency on `ForgeDetectors`. Detectors
/// also use this protocol for the same reason — tests mock the runner
/// instead of stubbing out the filesystem.
public protocol CommandRunner: Sendable {
    func run(executable: URL, arguments: [String]) throws -> CommandResult
}

/// Captured output of a subprocess invocation.
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

/// Production `CommandRunner` that shells out via `Process`. Used by every
/// detector and by every diagnostics provider that needs to invoke a CLI
/// tool. Tests inject a `FakeCommandRunner` (declared inline in each test
/// file) that records calls and returns scripted results.
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
