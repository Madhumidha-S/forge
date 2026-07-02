import Foundation
import ForgeCore

/// Diagnostics for Ollama's on-disk footprint.
///
/// Subprocess call: `ollama list` which prints a table of installed models
/// with name, size, and modification time.
///
/// If `ollama` isn't installed, the diagnostic returns an empty array.
///
/// "Unused" model heuristic: we can't know which models are actually in
/// use from `ollama list` alone — that requires runtime telemetry. For
/// Phase 4 we surface "models older than 90 days that aren't the
/// currently-loaded model" as candidates for review. The UI can refine
/// this with telemetry in a later phase.
public struct OllamaDiagnostics: ToolDiagnostics, @unchecked Sendable {
    public let toolID: ToolID = .ollama
    public let displayName = "Ollama"

    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        let result = try await runOllama(arguments: ["list"], context: context)
        guard result.exitCode == 0 else { return [] }

        let models = Self.parseList(result.stdout)
        guard !models.isEmpty else { return [] }

        var issues: [DiagnosticIssue] = []

        let totalBytes = models.reduce(UInt64(0)) { $0 + $1.sizeBytes }
        if totalBytes >= 20_000_000_000 {
            issues.append(DiagnosticIssue(
                toolID: .ollama,
                title: "Ollama models",
                explanation: "Ollama models are consuming \(Self.formatBytes(totalBytes)). Large models dominate disk usage — prune unused ones with `ollama rm <model>`.",
                severity: .critical,
                estimatedSavingsBytes: totalBytes,
                fixAvailable: false,
                remediationText: "Run `ollama list` to see installed models, then `ollama rm <name>` for ones you don't use."
            ))
        } else if totalBytes >= 5_000_000_000 {
            issues.append(DiagnosticIssue(
                toolID: .ollama,
                title: "Ollama models",
                explanation: "Ollama models are consuming \(Self.formatBytes(totalBytes)).",
                severity: .warning,
                estimatedSavingsBytes: totalBytes,
                fixAvailable: false,
                remediationText: "Review installed models and remove unused ones with `ollama rm <model>`."
            ))
        }

        // "Unused" candidates — models older than 90 days.
        let staleCutoff = now().addingTimeInterval(-90 * 24 * 60 * 60)
        let staleModels = models.filter { $0.modified < staleCutoff }
        if !staleModels.isEmpty {
            let staleBytes = staleModels.reduce(UInt64(0)) { $0 + $1.sizeBytes }
            let names = staleModels.map(\.name).joined(separator: ", ")
            issues.append(DiagnosticIssue(
                toolID: .ollama,
                title: "Ollama unused models",
                explanation: "\(staleModels.count) model\(staleModels.count == 1 ? " was" : "s were") last modified more than 90 days ago (\(names)).",
                severity: .warning,
                estimatedSavingsBytes: staleBytes,
                fixAvailable: false,
                remediationText: "Run `ollama rm <model>` for each unused model to reclaim disk."
            ))
        }

        return issues
    }

    // MARK: - Subprocess

    private func runOllama(
        arguments: [String],
        context: DiagnosticsContext
    ) async throws -> CommandResult {
        try context.commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["ollama"] + arguments
        )
    }

    // MARK: - Parsing

    struct Model {
        let name: String
        let sizeBytes: UInt64
        let modified: Date
    }

    /// Parses the default `ollama list` output. Columns:
    /// NAME                ID            SIZE      MODIFIED
    /// codellama:13b       9f438cb9......  7.3 GB    4 days ago
    ///
    /// Column widths vary; we split by whitespace runs (2+ spaces).
    static func parseList(_ stdout: String) -> [Model] {
        let lines = stdout.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        // Skip header.
        guard lines.count >= 2 else { return [] }
        let dataLines = lines.dropFirst()

        // Determine column boundaries from the header.
        let header = lines[0]
        let columns = splitColumns(header)

        var models: [Model] = []
        let referenceDate = Date()
        for line in dataLines {
            let fields = splitColumns(line)
            guard fields.count >= 3 else { continue }

            // Field 0: NAME, 1: ID, 2: SIZE, 3+: MODIFIED (free-form).
            let name = fields[0]
            let sizeBytes = parseSize(fields[2])
            let modified = parseModified(fields.dropFirst(3).joined(separator: " "), relativeTo: referenceDate)
            models.append(Model(name: name, sizeBytes: sizeBytes, modified: modified))
        }
        return models
    }

    /// Splits a line on 2+ space boundaries (preserves single spaces within
    /// fields like `days ago`).
    private static func splitColumns(_ line: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "  +")
        let range = NSRange(line.startIndex..., in: line)
        let matches = pattern.matches(in: line, range: range)
        guard !matches.isEmpty else { return [line] }
        var columns: [String] = []
        var cursor = line.startIndex
        for match in matches {
            if let r = Range(match.range, in: line), cursor < r.lowerBound {
                columns.append(String(line[cursor..<r.lowerBound]).trimmingCharacters(in: .whitespaces))
                cursor = r.upperBound
            }
        }
        if cursor < line.endIndex {
            columns.append(String(line[cursor...]).trimmingCharacters(in: .whitespaces))
        }
        return columns.filter { !$0.isEmpty }
    }

    static func parseSize(_ raw: String) -> UInt64 {
        // Reuse DockerDiagnostics.parseSize — same format ("7.3 GB").
        DockerDiagnostics.parseSize(raw)
    }

    /// Parses "4 days ago", "2 weeks ago", "3 hours ago", "just now".
    /// Returns Date.distantPast for anything unparseable so the model is
    /// treated as "very stale" rather than "fresh".
    static func parseModified(_ raw: String, relativeTo reference: Date) -> Date {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "just now" {
            return reference
        }
        // Split "<number> <unit> ago".
        let parts = trimmed.split(separator: " ")
        guard parts.count >= 3, parts.last?.lowercased() == "ago" else {
            return .distantPast
        }
        guard let count = Int(parts[parts.count - 3]) else {
            return .distantPast
        }
        let unit = parts[parts.count - 2].lowercased()
        let seconds: TimeInterval
        switch unit {
        case "second", "seconds": seconds = 1
        case "minute", "minutes": seconds = 60
        case "hour", "hours":     seconds = 60 * 60
        case "day", "days":       seconds = 60 * 60 * 24
        case "week", "weeks":     seconds = 60 * 60 * 24 * 7
        case "month", "months":   seconds = 60 * 60 * 24 * 30
        case "year", "years":     seconds = 60 * 60 * 24 * 365
        default:                  return .distantPast
        }
        return reference.addingTimeInterval(-Double(count) * seconds)
    }

    // MARK: - Formatting

    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useTB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
