import Foundation

/// Errors common to all update provider implementations.
public enum UpdateProviderError: Error, Sendable, Equatable {
    /// The provider contract exists but the concrete implementation has not
    /// been written yet.
    case notImplemented
}
