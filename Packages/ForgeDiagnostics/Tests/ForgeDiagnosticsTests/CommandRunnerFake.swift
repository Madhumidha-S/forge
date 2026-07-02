import Foundation
import ForgeCore

// MARK: - FakeCommandRunner
//
// Shared `FakeCommandRunner` used by every subprocess-driven diagnostic test
// (Docker, Ollama, Homebrew, Python). Each test constructs one with a
// `script` closure that maps (executable, arguments) → `CommandResult`.

final class FakeCommandRunner: CommandRunner, @unchecked Sendable {
    struct Call {
        let executable: URL
        let arguments: [String]
    }

    private(set) var calls: [Call] = []
    let script: (URL, [String]) -> CommandResult

    init(script: @escaping (URL, [String]) -> CommandResult) {
        self.script = script
    }

    func run(executable: URL, arguments: [String]) throws -> CommandResult {
        calls.append(Call(executable: executable, arguments: arguments))
        return script(executable, arguments)
    }
}

// MARK: - Default scripts
//
// Convenience scripts that match the real CLI outputs the diagnostics parse.
// Tests can use these verbatim or compose their own.

extension FakeCommandRunner {

    /// `docker system df --format "{{.Type}}\t{{.Size}}\t{{.Reclaimable}}"`
    /// Uses hardcoded format strings instead of `ByteCountFormatter` to
    /// avoid any formatter-related variance or platform differences.
    static func dockerSystemDf(
        imagesBytes: UInt64,
        volumesBytes: UInt64,
        buildCacheBytes: UInt64
    ) -> (URL, [String]) -> CommandResult {
        return { _, args in
            if args.contains("system") {
                let stdout = """
                Images\t\(Self.dockerSize(imagesBytes))\t0B
                Containers\t0B\t0B
                Local Volumes\t\(Self.dockerSize(volumesBytes))\t0B
                Build Cache\t\(Self.dockerSize(buildCacheBytes))\t0B
                """
                return CommandResult(stdout: stdout, stderr: "", exitCode: 0)
            }
            if args.contains("ps") {
                // Empty output — no stopped/orphan containers.
                return CommandResult(stdout: "", stderr: "", exitCode: 0)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 1)
        }
    }

    /// Formats a byte count as a Docker-style size string. Uses the
    /// decimal (1000-based) units that `docker system df` emits.
    /// Hardcoded to keep the test output deterministic.
    static func dockerSize(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0B" }
        let kb = Double(bytes) / 1_000
        if kb < 1_000 { return "\(Int(kb))KB" }
        let mb = kb / 1_000
        if mb < 1_000 { return "\(formatDecimal(mb))MB" }
        let gb = mb / 1_000
        if gb < 1_000 { return "\(formatDecimal(gb))GB" }
        let tb = gb / 1_000
        return "\(formatDecimal(tb))TB"
    }

    private static func formatDecimal(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    /// `docker ps -a --filter status=exited --format "{{.ID}}"`
    static func dockerPs(filter: String, ids: [String]) -> (URL, [String]) -> CommandResult {
        return { _, args in
            if args.contains("ps") && args.contains(filter) {
                return CommandResult(stdout: ids.joined(separator: "\n") + "\n", stderr: "", exitCode: 0)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 1)
        }
    }

    /// `docker` not installed.
    static let dockerMissing: @Sendable (URL, [String]) -> CommandResult = { _, _ in
        CommandResult(stdout: "", stderr: "docker: command not found", exitCode: 127)
    }

    /// `ollama list` — header + rows of "name<TAB>id<TAB>size<TAB>modified".
    static func ollamaList(models: [(name: String, sizeBytes: UInt64, modifiedRelativeSeconds: TimeInterval)]) -> (URL, [String]) -> CommandResult {
        return { _, args in
            if args.contains("list") {
                let header = "NAME                ID            SIZE      MODIFIED"
                let formatSize: (UInt64) -> String = { bytes in
                    let formatter = ByteCountFormatter()
                    formatter.countStyle = .binary
                    return formatter.string(fromByteCount: Int64(bytes))
                }
                let formatModified: (TimeInterval) -> String = { seconds in
                    let days = Int(seconds / 86400)
                    if days <= 0 { return "just now" }
                    if days == 1 { return "1 day ago" }
                    return "\(days) days ago"
                }
                let rows = models.map { m in
                    "\(m.name.padding(toLength: 20, withPad: " ", startingAt: 0))abc123  \(formatSize(m.sizeBytes))    \(formatModified(m.modifiedRelativeSeconds))"
                }
                let stdout = ([header] + rows).joined(separator: "\n") + "\n"
                return CommandResult(stdout: stdout, stderr: "", exitCode: 0)
            }
            // python3 -c "..." for the exec check
            if args.contains("-c") {
                return CommandResult(stdout: "/usr/local/bin/python3\n", stderr: "", exitCode: 0)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 1)
        }
    }

    /// `brew info --json=v2 --installed` — JSON array of formulae/casks.
    static func brewInfo(packages: [(name: String, outdated: Bool, installedOnRequest: Bool, pouredFromBottle: Bool)]) -> (URL, [String]) -> CommandResult {
        return { _, _ in
            let formulae = packages.map { p -> [String: Any] in
                [
                    "name": p.name,
                    "installed": [["version": "1.0.0"]],
                    "outdated": p.outdated,
                    "installed_on_request": p.installedOnRequest,
                    "poured_from_bottle": p.pouredFromBottle
                ]
            }
            let json: [String: Any] = [
                "formulae": formulae,
                "casks": [] as [[String: Any]]
            ]
            let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
            return CommandResult(
                stdout: String(data: data, encoding: .utf8) ?? "{}",
                stderr: "",
                exitCode: 0
            )
        }
    }

    /// `brew --cache` → path on stdout.
    static func brewCache(_ path: String) -> (URL, [String]) -> CommandResult {
        return { _, args in
            if args == ["--cache"] {
                return CommandResult(stdout: path + "\n", stderr: "", exitCode: 0)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 1)
        }
    }

    /// `which -a python3` — newline-separated paths.
    static func whichPython3(paths: [String]) -> (URL, [String]) -> CommandResult {
        return { _, args in
            if args == ["-a", "python3"] {
                if paths.isEmpty {
                    return CommandResult(stdout: "", stderr: "no python3 in PATH", exitCode: 1)
                }
                return CommandResult(stdout: paths.joined(separator: "\n") + "\n", stderr: "", exitCode: 0)
            }
            if args.contains("-c") {
                return CommandResult(stdout: (paths.first ?? "/usr/bin/python3") + "\n", stderr: "", exitCode: 0)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 1)
        }
    }
}
