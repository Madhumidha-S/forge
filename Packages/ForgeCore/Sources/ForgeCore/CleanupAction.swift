import Foundation

/// Protocol for cleanup actions that can estimate reclaimable space before
/// actually removing anything.
///
/// Conforming types must implement `dryRun()` to return a `DryRunReport`
/// describing what *would* be deleted. No commit/execute method is defined
/// here; this scaffold is intentionally dry-run only.
public protocol CleanupActionProtocol: Sendable {
    /// Stable identifier for the action, e.g. `xcode.derivedData`.
    var id: String { get }

    /// Human-readable label shown in the UI.
    var displayName: String { get }

    /// Scan the target and report what would be removed, without deleting
    /// anything.
    func dryRun() async throws -> DryRunReport
}

/// Marker protocol indicating a cleanup action is **trash-only**.
///
/// Conforming types must never call destructive removal APIs such as
/// `FileManager.removeItem(at:)` or shell out to `rm`. They must only move
/// items to the user Trash using `NSWorkspace.recycle(_:)` or
/// `FileManager.trashItem(at:resultingItemURL:)`.
///
/// There are no required methods — the contract is enforced by code review
/// and by the explicit marker conformance.
public protocol TrashOnly: Sendable {}

/// Report produced by a dry-run cleanup scan.
public struct DryRunReport: Sendable, Equatable {
    /// Display name of the cleanup target.
    public let target: String

    /// URLs that the action would move to trash.
    public let candidatePaths: [URL]

    /// Estimated total bytes that could be reclaimed.
    public let totalReclaimableBytes: Int64

    /// Timestamp when the scan completed.
    public let scannedAt: Date

    public init(
        target: String,
        candidatePaths: [URL],
        totalReclaimableBytes: Int64,
        scannedAt: Date = Date()
    ) {
        self.target = target
        self.candidatePaths = candidatePaths
        self.totalReclaimableBytes = totalReclaimableBytes
        self.scannedAt = scannedAt
    }
}
