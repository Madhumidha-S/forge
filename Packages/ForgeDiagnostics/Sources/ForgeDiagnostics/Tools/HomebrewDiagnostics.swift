import Foundation
import ForgeCore

/// Diagnostics for Homebrew's on-disk footprint and hygiene.
///
/// Two subprocess calls:
/// - `brew info --json=v2 --installed` → list of installed formulae/casks
///   with outdated flag, plus pinned/versions info
/// - `brew --cache --get-cache` → Homebrew cache directory path; we walk
///   that directory to compute total size
///
/// If `brew` isn't installed, the diagnostic returns an empty array.
public struct HomebrewDiagnostics: ToolDiagnostics, @unchecked Sendable {
    public let toolID: ToolID = .homebrew
    public let displayName = "Homebrew"

    private let cacheDirectory: URL?
    private let fileManager: FileManager

    public init(
        cacheDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.cacheDirectory = cacheDirectory
        self.fileManager = fileManager
    }

    public func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []

        // Outdated + orphan counts from `brew info --json=v2 --installed`.
        let infoResult = try await runBrew(
            arguments: ["info", "--json=v2", "--installed"],
            context: context
        )
        let packages = Self.parseInstalledPackages(infoResult.stdout)
        let outdated = packages.filter { $0.outdated }
        let orphans = packages.filter { $0.installedOnRequest == false && $0.pouredFromBottle }

        if !outdated.isEmpty {
            issues.append(DiagnosticIssue(
                toolID: .homebrew,
                title: "Outdated Homebrew packages",
                explanation: "\(outdated.isEmpty ? 0 : outdated.count) of your installed formulae are out of date. Run `brew upgrade` to update them.",
                severity: .warning,
                estimatedSavingsBytes: nil,
                fixAvailable: false,
                remediationText: "Run `brew upgrade` to update all outdated formulae. Use `brew upgrade <formula>` for individual packages."
            ))
        }

        if !orphans.isEmpty {
            let names = orphans.prefix(5).map(\.name).joined(separator: ", ")
            let more = orphans.count > 5 ? " and \(orphans.count - 5) more" : ""
            issues.append(DiagnosticIssue(
                toolID: .homebrew,
                title: "Orphan Homebrew packages",
                explanation: "These packages were installed as dependencies but are no longer required: \(names)\(more).",
                severity: .info,
                estimatedSavingsBytes: nil,
                fixAvailable: false,
                remediationText: "Run `brew autoremove` to remove orphaned dependencies."
            ))
        }

        // Cache size — walk `brew --cache` if available, else use injected.
        let cacheURL: URL?
        if let cacheDirectory {
            cacheURL = cacheDirectory
        } else {
            let cacheResult = try await runBrew(
                arguments: ["--cache"],
                context: context
            )
            cacheURL = cacheResult.exitCode == 0
                ? URL(fileURLWithPath: cacheResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
                : nil
        }
        if let cacheURL {
            let size = directorySize(at: cacheURL)
            if size >= 1_000_000_000 {
                issues.append(DiagnosticIssue(
                    toolID: .homebrew,
                    title: "Homebrew cache",
                    explanation: "Homebrew's download cache is large. `brew cleanup` removes stale downloads.",
                    severity: .warning,
                    estimatedSavingsBytes: size,
                    fixAvailable: false,
                    remediationText: "Run `brew cleanup` to remove stale downloads from the cache."
                ))
            }
        }

        return issues
    }

    // MARK: - Subprocess

    private func runBrew(
        arguments: [String],
        context: DiagnosticsContext
    ) async throws -> CommandResult {
        try context.commandRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["brew"] + arguments
        )
    }

    // MARK: - Parsing

    struct InstalledPackage {
        let name: String
        let outdated: Bool
        let installedOnRequest: Bool
        let pouredFromBottle: Bool
    }

    /// Parses `brew info --json=v2 --installed` output. JSON structure:
    /// {
    ///   "formulae": [
    ///     { "name": "git", "installed": [{"version": "2.45.0"}],
    ///       "outdated": true, "installed_on_request": true,
    ///       "poured_from_bottle": true, ... },
    ///     ...
    ///   ],
    ///   "casks": [ ... ]
    /// }
    static func parseInstalledPackages(_ stdout: String) -> [InstalledPackage] {
        guard let data = stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        var packages: [InstalledPackage] = []
        for key in ["formulae", "casks"] {
            guard let array = json[key] as? [[String: Any]] else { continue }
            for entry in array {
                guard let name = entry["name"] as? String else { continue }
                let outdated = entry["outdated"] as? Bool ?? false
                let installedOnRequest = entry["installed_on_request"] as? Bool ?? false
                let pouredFromBottle = entry["poured_from_bottle"] as? Bool ?? false
                packages.append(InstalledPackage(
                    name: name,
                    outdated: outdated,
                    installedOnRequest: installedOnRequest,
                    pouredFromBottle: pouredFromBottle
                ))
            }
        }
        return packages
    }

    // MARK: - Directory size helper (duplicated from XcodeDiagnostics)

    /// Recursive directory size in bytes.
    ///
    /// Deduplicates by fileResourceIdentifier (volume + inode) so files
    /// reachable via multiple paths — including symlinks followed by
    /// `FileManager.enumerator`, which happens by default — are only
    /// counted once. Without this dedup, directories with symlinked
    /// subtrees (common in Xcode DerivedData, Homebrew cache, pub-cache,
    /// Gradle caches) get massively over-counted.
    private func directorySize(at url: URL) -> UInt64 {
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey,
            .fileSizeKey,
            .isSymbolicLinkKey,
            .fileResourceIdentifierKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: UInt64 = 0
        var visited: Set<String> = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let isFile = values.isRegularFile,
                  isFile,
                  values.isSymbolicLink != true,
                  let size = values.fileSize,
                  let identifier = values.fileResourceIdentifier
            else { continue }
            // Skip duplicates reached via multiple paths (e.g. symlink resolution).
            // String(description:) yields a stable per-inode key (volume id + resource id).
            let key = String(describing: identifier)
            if visited.contains(key) { continue }
            visited.insert(key)
            total &+= UInt64(size)
        }
        return total
    }
}
