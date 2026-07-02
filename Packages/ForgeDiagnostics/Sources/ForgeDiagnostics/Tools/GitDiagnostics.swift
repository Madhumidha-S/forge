import Foundation
import ForgeCore

/// Diagnostics for Git configuration hygiene.
///
/// Reads `~/.gitconfig` and surfaces common misconfigurations:
/// - Missing `[user] name`
/// - Missing `[user] email`
/// - Missing `[init] defaultBranch`
///
/// All three are `.warning` (not `.critical`) — they're quality-of-life
/// issues that don't break git, but they do break tools that assume
/// they're set (commits without identity, new repos with surprising
/// default branch names, etc.).
///
/// If the file doesn't exist (no git config yet) or can't be read, the
/// diagnostic returns the "missing user.name" and "missing user.email"
/// issues — those are real regardless of file presence.
public struct GitDiagnostics: ToolDiagnostics, @unchecked Sendable {
    public let toolID: ToolID = .git
    public let displayName = "Git"

    private let configFileURL: URL?
    private let fileManager: FileManager

    public init(
        configFileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.configFileURL = configFileURL
        self.fileManager = fileManager
    }

    public func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        let url = configFileURL ?? Self.defaultConfigFile(home: context.homeDirectory)
        let contents: String?
        if let url, fileManager.fileExists(atPath: url.path) {
            contents = try? String(contentsOf: url, encoding: .utf8)
        } else {
            contents = nil
        }

        let sections = Self.parseGitConfig(contents)
        var issues: [DiagnosticIssue] = []

        // user.name
        if sections["user"]?["name"] == nil {
            issues.append(DiagnosticIssue(
                toolID: .git,
                title: "Git user.name not set",
                explanation: "Your global Git config doesn't have a `[user] name`. Commits will fail until this is set.",
                severity: .warning,
                fixAvailable: false,
                remediationText: "Run `git config --global user.name \"Your Name\"`."
            ))
        }

        // user.email
        if sections["user"]?["email"] == nil {
            issues.append(DiagnosticIssue(
                toolID: .git,
                title: "Git user.email not set",
                explanation: "Your global Git config doesn't have a `[user] email`. Commits will fail until this is set.",
                severity: .warning,
                fixAvailable: false,
                remediationText: "Run `git config --global user.email \"you@example.com\"`."
            ))
        }

        // init.defaultBranch
        if sections["init"]?["defaultBranch"] == nil {
            issues.append(DiagnosticIssue(
                toolID: .git,
                title: "Git defaultBranch not set",
                explanation: "Your global Git config doesn't have an `[init] defaultBranch`. New repos will use git's compile-time default (often `master`).",
                severity: .info,
                fixAvailable: false,
                remediationText: "Run `git config --global init.defaultBranch main` (or your preferred default)."
            ))
        }

        return issues
    }

    // MARK: - Default path

    private static func defaultConfigFile(home: URL?) -> URL? {
        home?.appendingPathComponent(".gitconfig", isDirectory: false)
    }

    // MARK: - Parsing

    /// Parses an INI-style git config file. Returns a nested map of
    /// `section → key → value`. Handles `[section]` and
    /// `[section "subsection"]` headers, but the subsections are flattened
    /// into the section name for our purposes. Comments (`#` and `;`) and
    /// blank lines are ignored.
    static func parseGitConfig(_ contents: String?) -> [String: [String: String]] {
        guard let contents, !contents.isEmpty else { return [:] }
        var result: [String: [String: String]] = [:]
        var currentSection = ""
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") || line.hasPrefix(";") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let inner = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                // Strip subsection: `[remote "origin"]` → `remote`
                if let quoteStart = inner.firstIndex(of: "\"") {
                    currentSection = String(inner[..<quoteStart]).trimmingCharacters(in: .whitespaces)
                } else {
                    currentSection = inner
                }
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            // Strip inline comments.
            if let hashIdx = value.firstIndex(of: "#") {
                value = String(value[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            }
            if let semiIdx = value.firstIndex(of: ";") {
                value = String(value[..<semiIdx]).trimmingCharacters(in: .whitespaces)
            }
            let sectionKey = currentSection.lowercased()
            result[sectionKey, default: [:]][key.lowercased()] = value
        }
        return result
    }
}
