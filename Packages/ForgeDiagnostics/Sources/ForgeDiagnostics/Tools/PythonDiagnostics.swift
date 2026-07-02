import Foundation
import ForgeCore

/// Diagnostics for Python installation hygiene.
///
/// Two subprocess calls:
/// - `which -a python3` → every `python3` on PATH, one per line
/// - `python3 -c "import sys; print(sys.executable)"` → the default
///   interpreter's path, used to cross-check "is the default on PATH?"
///
/// Issues surfaced:
/// - `.warning` if no `python3` is on PATH at all
/// - `.info` if multiple `python3` installations exist (helps the user
///   understand which one their `pip` is hitting)
public struct PythonDiagnostics: ToolDiagnostics {
    public let toolID: ToolID = .python
    public let displayName = "Python"

    public init() {}

    public func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        let whichResult = try await runPython(
            arguments: ["-a", "python3"],
            context: context
        )
        // `which` exits non-zero when nothing matches; that's not an error
        // for our purposes — it just means python3 is missing.
        let candidates = whichResult.exitCode == 0
            ? whichResult.stdout.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            : []

        var issues: [DiagnosticIssue] = []

        if candidates.isEmpty {
            issues.append(DiagnosticIssue(
                toolID: .python,
                title: "Python 3 not on PATH",
                explanation: "`python3` isn't on your PATH. Scripts that assume a system Python will fail. Install Python via Homebrew or python.org.",
                severity: .warning,
                fixAvailable: false,
                remediationText: "Install Python 3 via Homebrew (`brew install python`) or from python.org."
            ))
            return issues
        }

        if candidates.count >= 3 {
            issues.append(DiagnosticIssue(
                toolID: .python,
                title: "Multiple Python installations",
                explanation: "`which -a python3` found \(candidates.count) distinct python3 binaries on your PATH: \(candidates.joined(separator: ", ")). This can cause confusion when `pip install` lands in a different interpreter than the one your script uses.",
                severity: .info,
                fixAvailable: false,
                remediationText: "Decide on one canonical interpreter (e.g., Homebrew's) and use `python3 -m venv` for project-local environments."
            ))
        } else if candidates.count == 2 {
            issues.append(DiagnosticIssue(
                toolID: .python,
                title: "Two Python installations",
                explanation: "`which -a python3` found two python3 binaries: \(candidates.joined(separator: ", ")). Verify your shell resolves to the one you expect.",
                severity: .info,
                fixAvailable: false,
                remediationText: "Run `python3 -c 'import sys; print(sys.executable)'` to see which one is default."
            ))
        }

        // Check that the first (highest-priority) candidate is also a
        // working interpreter. If `which` returned a path but
        // `python3 -c ...` fails, that path is broken.
        let execResult = try await runPython(
            arguments: ["-c", "import sys; print(sys.executable)"],
            context: context
        )
        if execResult.exitCode != 0 {
            issues.append(DiagnosticIssue(
                toolID: .python,
                title: "Broken python3 on PATH",
                explanation: "The first `python3` on your PATH (\(candidates[0])) cannot execute a trivial script. This usually means a broken Homebrew symlink.",
                severity: .warning,
                fixAvailable: false,
                remediationText: "Run `brew reinstall python` or remove the broken symlink at \(candidates[0])."
            ))
        }

        return issues
    }

    // MARK: - Subprocess

    private func runPython(
        arguments: [String],
        context: DiagnosticsContext
    ) async throws -> CommandResult {
        try context.commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["python3"] + arguments
        )
    }
}
