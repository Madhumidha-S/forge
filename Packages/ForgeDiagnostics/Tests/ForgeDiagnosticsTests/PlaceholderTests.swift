import XCTest
@testable import ForgeDiagnostics

// Phase 4A placeholder. Real tests for the diagnostics engine and providers
// land in Phase 4B and 4C–4D.
final class PlaceholderTests: XCTestCase {
    func testPackageVersionIsReported() {
        XCTAssertEqual(ForgeDiagnosticsPackage.version, "0.4.0-phase4a")
    }
}
