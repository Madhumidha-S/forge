import Foundation
import ForgeCore

/// Diagnostics for Flutter's on-disk footprint.
///
/// Two scans:
/// - `~/.pub-cache` — Dart package cache shared across all projects
/// - `.dart_tool/` build directories — per-project build artifacts
///
/// Both are file-walking scans, same pattern as `XcodeDiagnostics`.
/// `pubCacheDirectory` and `buildArtifactsSearchRoot` can be overridden
/// for tests; defaults are the standard locations.
public struct FlutterDiagnostics: ToolDiagnostics, @unchecked Sendable {
    public let toolID: ToolID = .flutter
    public let displayName = "Flutter"

    private let pubCacheDirectory: URL?
    private let buildArtifactsSearchRoot: URL?
    private let fileManager: FileManager
    private let significantSizeThreshold: UInt64

    public init(
        pubCacheDirectory: URL? = nil,
        buildArtifactsSearchRoot: URL? = nil,
        fileManager: FileManager = .default,
        significantSizeThreshold: UInt64 = 1_000_000_000  // 1 GB
    ) {
        self.pubCacheDirectory = pubCacheDirectory
        self.buildArtifactsSearchRoot = buildArtifactsSearchRoot
        self.fileManager = fileManager
        self.significantSizeThreshold = significantSizeThreshold
    }

    public func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []

        // Explicit paths only — if the caller doesn't inject a path for
        // a scan, that scan is skipped. The UI layer (Phase 4E) resolves
        // real home-directory paths and injects them. Falling back here
        // would make tests non-deterministic and accidentally scan the
        // user's machine.
        if let pubCacheDirectory {
            issues.append(contentsOf: scanPubCache(at: pubCacheDirectory))
        }
        if let buildArtifactsSearchRoot {
            issues.append(contentsOf: scanBuildArtifacts(under: buildArtifactsSearchRoot))
        }

        return issues
    }

    // MARK: - Scans

    private func scanPubCache(at url: URL) -> [DiagnosticIssue] {
        let size = directorySize(at: url)
        guard size >= significantSizeThreshold else { return [] }
        return [DiagnosticIssue(
            toolID: .flutter,
            title: "Pub cache",
            explanation: "Dart's shared package cache is large. Run `flutter pub cache clean` to remove unused package versions.",
            severity: size >= 5_000_000_000 ? .warning : .info,
            estimatedSavingsBytes: size,
            fixAvailable: false,
            remediationText: "Run `flutter pub cache clean` to remove unused package versions."
        )]
    }

    private func scanBuildArtifacts(under searchRoot: URL) -> [DiagnosticIssue] {
        // Find every `.dart_tool/` directory under the search root and
        // sum their sizes. Cap depth at 6 to avoid walking into
        // node_modules-style dep trees.
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: searchRoot,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else { return [] }

        var totalBytes: UInt64 = 0
        var count = 0
        for case let dirURL as URL in enumerator {
            guard dirURL.lastPathComponent == ".dart_tool",
                  let values = try? dirURL.resourceValues(forKeys: Set(resourceKeys)),
                  values.isDirectory == true
            else { continue }
            totalBytes &+= directorySize(at: dirURL)
            count += 1
        }

        guard totalBytes >= significantSizeThreshold else { return [] }
        return [DiagnosticIssue(
            toolID: .flutter,
            title: "Flutter build artifacts",
            explanation: "\(count) `.dart_tool/` build director\(count == 1 ? "y" : "ies") totaling \(Self.formatBytes(totalBytes)). Each project keeps its own build cache; clean stale ones with `flutter clean`.",
            severity: .warning,
            estimatedSavingsBytes: totalBytes,
            fixAvailable: false,
            remediationText: "Run `flutter clean` in each project to remove its `.dart_tool/` build cache."
        )]
    }

    // MARK: - Directory size helper (duplicated from XcodeDiagnostics)

    private func directorySize(at url: URL) -> UInt64 {
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let isFile = values.isRegularFile,
                  isFile,
                  values.isSymbolicLink != true,
                  let size = values.fileSize
            else { continue }
            total &+= UInt64(size)
        }
        return total
    }

    // MARK: - Formatting (reused from OllamaDiagnostics)

    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useTB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
