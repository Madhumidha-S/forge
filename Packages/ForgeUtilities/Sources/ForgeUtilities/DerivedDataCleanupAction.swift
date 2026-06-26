import Foundation
import ForgeCore

/// Dry-run cleanup action that scans Xcode's DerivedData directory.
///
/// Conforms to `TrashOnly` so future maintainers know the implementation
/// must never invoke destructive removal APIs. The scaffold ships with
/// `dryRun()` only — there is no `execute()`.
public struct DerivedDataCleanupAction: CleanupActionProtocol, TrashOnly {
    public let id: String
    public let displayName: String
    public let rootURL: URL

    /// Default root: ~/Library/Developer/Xcode/DerivedData
    public init(rootURL: URL? = nil) {
        self.id = "xcode.derivedData"
        self.displayName = "Xcode DerivedData"
        if let rootURL {
            self.rootURL = rootURL
        } else {
            self.rootURL = URL(
                fileURLWithPath: NSString(string: "~/Library/Developer/Xcode/DerivedData").expandingTildeInPath,
                isDirectory: true
            )
        }
    }

    public func dryRun() async throws -> DryRunReport {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return DryRunReport(
                target: displayName,
                candidatePaths: [],
                totalReclaimableBytes: 0,
                scannedAt: Date()
            )
        }

        let directories = entries.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        var totalBytes: Int64 = 0
        for dir in directories {
            totalBytes &+= Self.recursiveSize(at: dir)
        }

        return DryRunReport(
            target: displayName,
            candidatePaths: directories.sorted { $0.path < $1.path },
            totalReclaimableBytes: totalBytes,
            scannedAt: Date()
        )
    }

    /// Sums on-disk byte counts for all regular files under `url`, recursively,
    /// without following symlinks. Returns 0 if the path is missing or unreadable.
    private static func recursiveSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else { continue }
            if values.isSymbolicLink == true { continue }
            if values.isRegularFile == true {
                total &+= Int64(values.fileSize ?? 0)
            }
        }
        return total
    }
}
