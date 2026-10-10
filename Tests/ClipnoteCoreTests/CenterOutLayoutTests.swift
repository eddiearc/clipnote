import XCTest
@testable import ClipnoteCore

final class CenterOutLayoutTests: XCTestCase {
    func testEmptyAndSingle() {
        XCTAssertTrue(CenterOutLayout.displayOrder([Int]()).isEmpty)
        XCTAssertEqual(CenterOutLayout.displayOrder([1]), [1])
    }

    func testAlternatesLeftThenRight() {
        XCTAssertEqual(CenterOutLayout.displayOrder([1, 2]), [2, 1])
        XCTAssertEqual(CenterOutLayout.displayOrder([1, 2, 3]), [2, 1, 3])
        XCTAssertEqual(CenterOutLayout.displayOrder([1, 2, 3, 4, 5]), [4, 2, 1, 3, 5])
    }
}
