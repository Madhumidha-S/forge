import Foundation
import ForgeCore

/// Diagnostics for Docker's on-disk footprint.
///
/// Two subprocess calls:
/// - `docker system df` → total image size, total volume size, build cache size
/// - `docker ps -a --filter status=exited` → stopped container count
/// - `docker ps -a --filter status=created` → orphan container count
///
/// If `docker` isn't installed (exit code 127 / "command not found"), the
/// diagnostic returns an empty array. We don't surface a "Docker not
/// installed" issue — that's the detector's job, not the diagnostic's.
public struct DockerDiagnostics: ToolDiagnostics {
    public let toolID: ToolID = .docker
    public let displayName = "Docker"

    public init() {}

    public func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []

        // Sizes — `docker system df` output format:
        // TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
        // Images          5         2         12.3GB    8.1GB (67%)
        // Containers      3         1         234MB     0B (0%)
        // Local Volumes   4         1         1.2GB     200MB (16%)
        // Build Cache     12        0         4.5GB     4.5GB
        let dfResult = try await runDocker(
            arguments: ["system", "df", "--format", "{{.Type}}\t{{.Size}}\t{{.Reclaimable}}"],
            context: context
        )
        if let df = parseSystemDf(dfResult.stdout) {
            issues.append(contentsOf: makeSizeIssues(from: df))
        }

        // Stopped containers.
        let stoppedResult = try await runDocker(
            arguments: ["ps", "-a", "--filter", "status=exited", "--format", "{{.ID}}"],
            context: context
        )
        let stoppedCount = stoppedResult.stdout.split(separator: "\n", omittingEmptySubsequences: true).count
        if stoppedCount > 0 {
            issues.append(DiagnosticIssue(
                toolID: .docker,
                title: "Docker stopped containers",
                explanation: "There are \(stoppedCount) stopped container\(stoppedCount == 1 ? "" : "s") holding disk space. Stopped containers are not running but their filesystem layers are still on disk.",
                severity: .warning,
                estimatedSavingsBytes: nil,
                fixAvailable: false,
                remediationText: "Run `docker container prune` to remove all stopped containers."
            ))
        }

        // Orphan containers (created but never started).
        let orphanResult = try await runDocker(
            arguments: ["ps", "-a", "--filter", "status=created", "--format", "{{.ID}}"],
            context: context
        )
        let orphanCount = orphanResult.stdout.split(separator: "\n", omittingEmptySubsequences: true).count
        if orphanCount > 0 {
            issues.append(DiagnosticIssue(
                toolID: .docker,
                title: "Docker orphan containers",
                explanation: "There are \(orphanCount) created-but-never-started container\(orphanCount == 1 ? "" : "s"). These are typically leftovers from interrupted `docker run` invocations.",
                severity: .info,
                estimatedSavingsBytes: nil,
                fixAvailable: false,
                remediationText: "Run `docker container prune --filter until=1h` to remove orphans older than 1 hour."
            ))
        }

        return issues
    }

    // MARK: - Subprocess

    private func runDocker(
        arguments: [String],
        context: DiagnosticsContext
    ) async throws -> CommandResult {
        try context.commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["docker"] + arguments
        )
    }

    // MARK: - Parsing

    private struct SystemDf {
        var imageBytes: UInt64
        var volumeBytes: UInt64
        var buildCacheBytes: UInt64
    }

    /// Parses the `--format` output of `docker system df`. Returns nil if
    /// the output doesn't match expected shape (e.g. empty, or `docker` not
    /// installed and the shell printed an error to stdout).
    private func parseSystemDf(_ stdout: String) -> SystemDf? {
        var df = SystemDf(imageBytes: 0, volumeBytes: 0, buildCacheBytes: 0)
        var foundAny = false
        for line in stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: true).map(String.init)
            guard columns.count >= 2 else { continue }
            let type = columns[0]
            // `docker system df --format "{{.Type}}\t{{.Size}}\t{{.Reclaimable}}"`
            // emits the raw size string like "12.3GB" or "234MB" in column 2.
            // We don't use the Reclaimable column — we conservatively report
            // total size, leaving Reclaimable to the UI.
            let size = Self.parseSize(columns[1])
            foundAny = true
            switch type {
            case "Images":
                df.imageBytes = size
            case "Local Volumes":
                df.volumeBytes = size
            case "Build Cache":
                df.buildCacheBytes = size
            default:
                break
            }
        }
        return foundAny ? df : nil
    }

    /// Parses a Docker size string like "12.3GB", "234MB", "0B", "12 GB",
    /// or "0 bytes" into bytes. Tolerant of whitespace between the number
    /// and the unit, and of arbitrary unit spellings that contain no
    /// recognised suffix (returns 0 in that case).
    static func parseSize(_ raw: String) -> UInt64 {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }

        // Find the boundary between digits/decimal and the unit suffix.
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex, trimmed[idx].isNumber || trimmed[idx] == "." {
            idx = trimmed.index(after: idx)
        }
        // If we never advanced (no leading digit) or consumed the whole
        // string (no unit), bail.
        guard idx > trimmed.startIndex, idx < trimmed.endIndex else { return 0 }

        let numberPart = String(trimmed[trimmed.startIndex..<idx])
        // Strip all whitespace and uppercase before matching the unit.
        let unitPart = String(trimmed[idx...])
            .trimmingCharacters(in: .whitespaces)
            .uppercased()

        guard let value = Double(numberPart) else { return 0 }
        let multiplier: Double
        switch unitPart {
        case "B", "BYTES":            multiplier = 1
        case "KB", "KIB", "K":        multiplier = 1_000
        case "MB", "MIB", "M":        multiplier = 1_000_000
        case "GB", "GIB", "G":        multiplier = 1_000_000_000
        case "TB", "TIB", "T":        multiplier = 1_000_000_000_000
        default:                       multiplier = 1
        }
        return UInt64(value * multiplier)
    }

    private func makeSizeIssues(from df: SystemDf) -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []
        if df.imageBytes >= 10_000_000_000 {
            issues.append(DiagnosticIssue(
                toolID: .docker,
                title: "Docker images",
                explanation: "Docker images are consuming significant disk space. Old images can be pruned with `docker image prune -a`.",
                severity: .critical,
                estimatedSavingsBytes: df.imageBytes,
                fixAvailable: false,
                remediationText: "Run `docker image prune -a` to remove all unused images."
            ))
        } else if df.imageBytes >= 1_000_000_000 {
            issues.append(DiagnosticIssue(
                toolID: .docker,
                title: "Docker images",
                explanation: "Docker images are consuming significant disk space.",
                severity: .warning,
                estimatedSavingsBytes: df.imageBytes,
                fixAvailable: false,
                remediationText: "Run `docker image prune` to remove dangling images."
            ))
        }
        if df.volumeBytes >= 5_000_000_000 {
            issues.append(DiagnosticIssue(
                toolID: .docker,
                title: "Docker volumes",
                explanation: "Docker volumes are consuming significant disk space. Use `docker volume prune` to remove unused volumes.",
                severity: .warning,
                estimatedSavingsBytes: df.volumeBytes,
                fixAvailable: false,
                remediationText: "Run `docker volume prune` to remove unused volumes."
            ))
        }
        if df.buildCacheBytes >= 2_000_000_000 {
            issues.append(DiagnosticIssue(
                toolID: .docker,
                title: "Docker build cache",
                explanation: "Docker build cache is large. `docker builder prune` reclaims it without affecting images.",
                severity: .info,
                estimatedSavingsBytes: df.buildCacheBytes,
                fixAvailable: false,
                remediationText: "Run `docker builder prune` to reclaim build cache."
            ))
        }
        return issues
    }
}
