import Foundation

/// Canonical identifiers for the developer tools tracked by Forge.
public enum ToolID: String, Sendable, CaseIterable {
    case xcode
    case androidStudio
    case docker
    case homebrew
    case node
    case python
    case java
    case flutter
    case postgresql
    case ollama
    case git
    case vscode
}

/// A simple semantic-version value type.
public struct SemVer: Equatable, Hashable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses strings such as `v1.2.3`, `1.2.3`, or `1.2`.
    ///
    /// Returns `nil` if the string does not match a two- or three-component
    /// dot-separated version with optional leading "v".
    public init?(parsing string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed

        let components = withoutPrefix.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2 || components.count == 3 else { return nil }

        guard let major = Int(components[0]), major >= 0,
              let minor = Int(components[1]), minor >= 0 else {
            return nil
        }

        var patch = 0
        if components.count == 3 {
            guard let p = Int(components[2]), p >= 0 else { return nil }
            patch = p
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }
}
