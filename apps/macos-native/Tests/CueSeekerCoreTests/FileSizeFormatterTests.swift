import XCTest
@testable import CueSeekerCore

final class FileSizeFormatterTests: XCTestCase {
    func testZeroAndNegativeBytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 0), "0 B")
        XCTAssertEqual(FileSizeFormatter.format(bytes: -10), "0 B")
    }

    func testBytesBelow1000() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1), "1 B")
        XCTAssertEqual(FileSizeFormatter.format(bytes: 512), "512 B")
        XCTAssertEqual(FileSizeFormatter.format(bytes: 999), "999 B")
    }

    func testKilobytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1000), "1.00 KB")
        XCTAssertEqual(FileSizeFormatter.format(bytes: 102_350), "102.35 KB")
    }

    func testMegabytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1_000_000), "1.00 MB")
        XCTAssertEqual(FileSizeFormatter.format(bytes: 15_500_000), "15.50 MB")
    }

    func testGigabytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1_430_000_000), "1.43 GB")
        XCTAssertEqual(FileSizeFormatter.format(bytes: 2_150_000_000), "2.15 GB")
    }
}
