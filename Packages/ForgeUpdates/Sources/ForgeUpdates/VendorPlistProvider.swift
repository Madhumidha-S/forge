import Foundation
import ForgeCore

/// Stub for reading the latest version from a vendor feed plist.
///
/// FUTURE PHASE: This stub is intentionally unimplemented. A future
/// increment will replace its body with a plist download and parse of
/// the vendor's software-update feed. The scaffold exists only to
/// demonstrate the contract.
public struct VendorPlistProvider: UpdateProvider {
    public let id = "vendor.plist"
    public let displayName = "Vendor Info.plist"

    public init() {}

    public func latestVersion(for toolId: ToolID) async throws -> String {
        throw UpdateProviderError.notImplemented
    }
}
