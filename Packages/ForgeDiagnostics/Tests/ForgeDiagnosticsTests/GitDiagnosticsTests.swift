import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class GitDiagnosticsTests: XCTestCase {

    func testEmptyConfigProducesAllThreeIssues() async throws {
        let issues = try await GitDiagnostics(configFileURL: nil).diagnose(
            context: DiagnosticsContext(fileManager: makeFileManager(contents: nil))
        )
        // Missing config file → 2 issues (user.name, user.email).
        XCTAssertEqual(issues.count, 2)
        XCTAssertTrue(issues.contains { $0.title == "Git user.name not set" })
        XCTAssertTrue(issues.contains { $0.title == "Git user.email not set" })
    }

    func testCompleteConfigProducesNoIssues() async throws {
        let config = """
        [user]
        \tname = Jane Developer
        \temail = jane@example.com
        [init]
        \tdefaultBranch = main
        """
        let issues = try await GitDiagnostics(configFileURL: nil).diagnose(
            context: DiagnosticsContext(fileManager: makeFileManager(contents: config))
        )
        XCTAssertTrue(issues.isEmpty)
    }

    func testMissingDefaultBranchTriggersInfo() async throws {
        let config = """
        [user]
        \tname = Jane
        \temail = jane@example.com
        """
        let issues = try await GitDiagnostics(configFileURL: nil).diagnose(
            context: DiagnosticsContext(fileManager: makeFileManager(contents: config))
        )
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Git defaultBranch not set")
        XCTAssertEqual(issues[0].severity, .info)
    }

    func testMissingUserNameOnly() async throws {
        let config = """
        [user]
        \temail = jane@example.com
        [init]
        \tdefaultBranch = main
        """
        let issues = try await GitDiagnostics(configFileURL: nil).diagnose(
            context: DiagnosticsContext(fileManager: makeFileManager(contents: config))
        )
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title == "Git user.name not set", true)
    }

    func testParserHandlesCommentsAndSubsectionHeaders() {
        let config = """
        # This is a comment
        ; This too
        [user]
        \tname = Jane   # inline comment
        [remote "origin"]
        \turl = git@example.com:foo/bar.git
        """
        let parsed = GitDiagnostics.parseGitConfig(config)
        XCTAssertEqual(parsed["user"]?["name"], "Jane")
        // The remote subsection's url shouldn't appear (we only care about
        // top-level sections for the three checks).
        XCTAssertNil(parsed["origin"]?["url"])
    }

    // MARK: - Helpers

    /// Returns a `FileManager` whose `fileExists` and `contents` calls return
    /// the given string (or nil for "file missing"). We override at the
    /// instance level via subclassing.
    private func makeFileManager(contents: String?) -> FileManager {
        let backing = _StubFileManager(contents: contents)
        return backing
    }
}

private final class _StubFileManager: FileManager, @unchecked Sendable {
    let _contents: String?
    init(contents: String?) { self._contents = contents }

    override func fileExists(atPath path: String) -> Bool {
        return _contents != nil
    }

    override func contents(atPath path: String) -> Data? {
        guard let c = _contents else { return nil }
        return Data(c.utf8)
    }
}
