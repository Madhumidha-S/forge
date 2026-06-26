import XCTest
@testable import ForgeUI

final class ForgeUITests: XCTestCase {
    func testToolRowRendersName() {
        let row = ToolRow(name: "Node")
        XCTAssertEqual(row.name, "Node")
    }
}
