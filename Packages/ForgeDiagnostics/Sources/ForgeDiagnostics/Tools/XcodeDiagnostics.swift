import Foundation
import ForgeCore

/// Diagnostics for Xcode's on-disk footprint.
///
/// Scans four locations under the user's Developer directory:
/// - `DerivedData` — build artifacts cached per project
/// - `Archives` — release builds archived for distribution
/// - DeviceSupport` — symbol caches for connecting to physical devices
///
/// Plus the CoreSimulator caches, which sit outside the Developer dir.
///
/// Each scan produces zero or one `DiagnosticIssue`. The diagnostic
/// returns an empty array when no scan crosses the `significantSizeThreshold`
/// (default 1 GB), so a clean machine doesn't surface noise.
///
/// Path injection
/// --------------
/// `developerDirectory` and `coreSimulatorDirectory` default to the
/// standard `~/Library/Developer/{Xcode,CoreSimulator}` paths but can be
/// overridden by callers — tests use this to point at fixture trees
/// instead of the real machine.
///
/// `Sendable` is opted into via `@unchecked` because `FileManager` is not
/// declared `Sendable` by Foundation. The instance is safe to share
/// across actors: the default `FileManager` is documented thread-safe
/// for read-only filesystem operations, and `diagnose(context:)` never
/// mutates shared state on the file manager.
public struct XcodeDiagnostics: ToolDiagnostics, @unchecked Sendable {
    public let toolID: ToolID = .xcode
    public let displayName = "Xcode"

    private let developerDirectory: URL?
    private let coreSimulatorDirectory: URL?
    private let fileManager: FileManager
    private let significantSizeThreshold: UInt64

    public init(
        developerDirectory: URL? = nil,
        coreSimulatorDirectory: URL? = nil,
        fileManager: FileManager = .default,
        significantSizeThreshold: UInt64 = 1_000_000_000  // 1 GB
    ) {
        self.developerDirectory = developerDirectory
        self.coreSimulatorDirectory = coreSimulatorDirectory
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
        if let developerDirectory {
            let derivedData = developerDirectory.appendingPathComponent("DerivedData", isDirectory: true)
            issues.append(contentsOf: scanDerivedData(at: derivedData))
            let archives = developerDirectory.appendingPathComponent("Archives", isDirectory: true)
            issues.append(contentsOf: scanArchives(at: archives))
            let deviceSupportiOS = developerDirectory.appendingPathComponent("iOS DeviceSupport", isDirectory: true)
            issues.append(contentsOf: scanDeviceSupport(at: deviceSupportiOS, platform: "iOS"))
            let deviceSupporttvOS = developerDirectory.appendingPathComponent("tvOS DeviceSupport", isDirectory: true)
            issues.append(contentsOf: scanDeviceSupport(at: deviceSupporttvOS, platform: "tvOS"))
            let deviceSupportwatchOS = developerDirectory.appendingPathComponent("watchOS DeviceSupport", isDirectory: true)
            issues.append(contentsOf: scanDeviceSupport(at: deviceSupportwatchOS, platform: "watchOS"))
        }
        if let coreSimulatorDirectory {
            issues.append(contentsOf: scanSimulatorCaches(at: coreSimulatorDirectory))
        }

        return issues
    }

    // MARK: - Scans

    private func scanDerivedData(at url: URL) -> [DiagnosticIssue] {
        let size = directorySize(at: url)
        guard size >= significantSizeThreshold else { return [] }
        return [DiagnosticIssue(
            toolID: .xcode,
            title: "Xcode DerivedData",
            explanation: "Build artifacts have accumulated across your projects. DerivedData is safe to delete — Xcode will rebuild it on the next compile.",
            severity: size >= 10_000_000_000 ? .critical : .warning,
            estimatedSavingsBytes: size,
            fixAvailable: true,
            remediationText: "Clean DerivedData. Xcode will rebuild it lazily on the next build."
        )]
    }

    private func scanArchives(at url: URL) -> [DiagnosticIssue] {
        let size = directorySize(at: url)
        guard size >= significantSizeThreshold else { return [] }
        return [DiagnosticIssue(
            toolID: .xcode,
            title: "Xcode Archives",
            explanation: "Archived release builds are kept in Xcode's Archives folder. Old archives can be deleted if you've already uploaded them to App Store Connect or TestFlight.",
            severity: size >= 5_000_000_000 ? .warning : .info,
            estimatedSavingsBytes: size,
            fixAvailable: false,
            remediationText: "Open Xcode → Organizer → Archives and delete old ones manually."
        )]
    }

    private func scanSimulatorCaches(at url: URL) -> [DiagnosticIssue] {
        // CoreSimulator caches live at <CoreSimulator>/Caches.
        let cachesURL = url.appendingPathComponent("Caches", isDirectory: true)
        let size = directorySize(at: cachesURL)
        guard size >= significantSizeThreshold else { return [] }
        return [DiagnosticIssue(
            toolID: .xcode,
            title: "Simulator Caches",
            explanation: "The iOS Simulator's runtime caches (CoreSimulator/Caches) have grown large. Deleting them is safe — running simulators will rebuild their caches lazily.",
            severity: .warning,
            estimatedSavingsBytes: size,
            fixAvailable: false,
            remediationText: "Quit the Simulator, then delete ~/Library/Developer/CoreSimulator/Caches."
        )]
    }

    private func scanDeviceSupport(at url: URL, platform: String) -> [DiagnosticIssue] {
        let size = directorySize(at: url)
        guard size >= significantSizeThreshold else { return [] }
        return [DiagnosticIssue(
            toolID: .xcode,
            title: "\(platform) DeviceSupport",
            explanation: "Symbol caches for connecting to physical \(platform) devices. Old versions can be deleted — Xcode re-downloads them when you plug in a device running that iOS version.",
            severity: .warning,
            estimatedSavingsBytes: size,
            fixAvailable: false,
            remediationText: "Delete old version directories from \(url.path)."
        )]
    }

    // MARK: - Directory size helper

    /// Recursive directory size in bytes. Skips files we can't stat
    /// (permission denied, broken symlinks) rather than failing the
    /// whole scan — we'd rather underreport than crash.
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
            total += UInt64(size)
        }
        return total
    }
}
