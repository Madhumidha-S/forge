import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class FlutterDiagnosticsTests: XCTestCase {

    private var tempRoot: URL?

    override func tearDownWithError() throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
        tempRoot = nil
    }

    func testCleanFixtureProducesNoIssues() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file(".pub-cache/hosted/pub.dev/foo-1.0.tar.gz", size: 100_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = FlutterDiagnostics(
            pubCacheDirectory: root.appendingPathComponent(".pub-cache"),
            buildArtifactsSearchRoot: root
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertTrue(issues.isEmpty, "100 MB pub-cache should not trigger (threshold is 1 GB)")
    }

    func testLargePubCacheTriggersInfo() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file(".pub-cache/hosted/pub.dev/big-pkg-1.0.tar.gz", size: 1_500_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = FlutterDiagnostics(
            pubCacheDirectory: root.appendingPathComponent(".pub-cache"),
            buildArtifactsSearchRoot: root
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Pub cache")
        XCTAssertEqual(issues[0].severity, .info)
    }

    func testLargePubCacheOver5GBTriggersWarning() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file(".pub-cache/hosted/pub.dev/big-pkg-1.0.tar.gz", size: 6_000_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = FlutterDiagnostics(
            pubCacheDirectory: root.appendingPathComponent(".pub-cache"),
            buildArtifactsSearchRoot: root
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].severity, .warning)
    }

    func testBuildArtifactsTriggersWarning() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file("projects/app1/.dart_tool/flutter_build/a.o", size: 800_000_000)
            builder.file("projects/app1/.dart_tool/flutter_build/b.o", size: 800_000_000)
            builder.file("projects/app2/.dart_tool/flutter_build/c.o", size: 800_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = FlutterDiagnostics(
            pubCacheDirectory: nil,
            buildArtifactsSearchRoot: root
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Flutter build artifacts")
        XCTAssertEqual(issues[0].severity, .warning)
        XCTAssertTrue(issues[0].explanation.contains("2"))  // 2 .dart_tool dirs
    }

    func testBothIssuesWhenBothTriggers() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file(".pub-cache/hosted/pub.dev/foo.tar.gz", size: 1_500_000_000)
            builder.file("projects/.dart_tool/big.o", size: 1_500_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = FlutterDiagnostics(
            pubCacheDirectory: root.appendingPathComponent(".pub-cache"),
            buildArtifactsSearchRoot: root
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 2)
        XCTAssertTrue(issues.contains { $0.title == "Pub cache" })
        XCTAssertTrue(issues.contains { $0.title == "Flutter build artifacts" })
    }
}
