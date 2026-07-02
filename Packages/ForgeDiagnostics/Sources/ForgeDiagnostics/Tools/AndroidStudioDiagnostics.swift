import Foundation
import ForgeCore

/// Diagnostics for Android Studio's on-disk footprint.
///
/// Three scans, all file-walking like XcodeDiagnostics:
/// - Android SDK → `~/Library/Android/sdk`
/// - Gradle cache → `~/.gradle/caches`
/// - Emulator storage → `~/Library/Android/virtual` (avd data + snapshots)
///
/// If Android Studio is not installed, all three directories will be
/// absent and the diagnostic returns an empty array.
public struct AndroidStudioDiagnostics: ToolDiagnostics, @unchecked Sendable {
    public let toolID: ToolID = .androidStudio
    public let displayName = "Android Studio"

    private let sdkDirectory: URL?
    private let gradleCacheDirectory: URL?
    private let emulatorDirectory: URL?
    private let fileManager: FileManager
    private let significantSizeThreshold: UInt64

    public init(
        sdkDirectory: URL? = nil,
        gradleCacheDirectory: URL? = nil,
        emulatorDirectory: URL? = nil,
        fileManager: FileManager = .default,
        significantSizeThreshold: UInt64 = 1_000_000_000  // 1 GB
    ) {
        self.sdkDirectory = sdkDirectory
        self.gradleCacheDirectory = gradleCacheDirectory
        self.emulatorDirectory = emulatorDirectory
        self.fileManager = fileManager
        self.significantSizeThreshold = significantSizeThreshold
    }

    public func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []

        // Explicit paths only — if the caller doesn't inject a path for
        // a scan, that scan is skipped. The UI layer (Phase 4E) is
        // responsible for resolving real home-directory paths and
        // injecting them. Falling back to real paths here would make
        // tests non-deterministic and accidentally scan the user's
        // machine.
        if let sdkDirectory {
            issues.append(contentsOf: scanDirectory(
                at: sdkDirectory,
                title: "Android SDK",
                explanation: "Android SDK is consuming disk space. Old platform versions and build-tools can be removed via Android Studio's SDK Manager.",
                severityAt5GB: .warning,
                remediationText: "Open Android Studio → SDK Manager and uninstall unused platforms and build-tools."
            ))
        }

        if let gradleCacheDirectory {
            issues.append(contentsOf: scanDirectory(
                at: gradleCacheDirectory,
                title: "Gradle cache",
                explanation: "Gradle's dependency cache is large. Run `gradle clean` or delete `~/.gradle/caches` to reclaim.",
                severityAt5GB: .warning,
                remediationText: "Run `rm -rf ~/.gradle/caches` to clear Gradle's download cache. Gradle will re-download what it needs."
            ))
        }

        if let emulatorDirectory {
            issues.append(contentsOf: scanDirectory(
                at: emulatorDirectory,
                title: "Android emulator storage",
                explanation: "Android emulator data (AVDs + snapshots) is large. Delete unused AVDs via Android Studio's AVD Manager.",
                severityAt5GB: .warning,
                remediationText: "Open Android Studio → AVD Manager and delete unused virtual devices."
            ))
        }

        return issues
    }

    // MARK: - Default paths

    private static func defaultSDK(home: URL?) -> URL? {
        home?.appendingPathComponent("Library/Android/sdk", isDirectory: true)
    }

    private static func defaultGradleCache(home: URL?) -> URL? {
        home?.appendingPathComponent(".gradle/caches", isDirectory: true)
    }

    private static func defaultEmulator(home: URL?) -> URL? {
        home?.appendingPathComponent(".android/avd", isDirectory: true)
    }

    // MARK: - Scans

    private func scanDirectory(
        at url: URL,
        title: String,
        explanation: String,
        severityAt5GB: DiagnosticSeverity,
        remediationText: String
    ) -> [DiagnosticIssue] {
        let size = directorySize(at: url)
        guard size >= significantSizeThreshold else { return [] }
        return [DiagnosticIssue(
            toolID: .androidStudio,
            title: title,
            explanation: explanation,
            severity: size >= 2_000_000_000 ? severityAt5GB : .info,
            estimatedSavingsBytes: size,
            fixAvailable: false,
            remediationText: remediationText
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
}
