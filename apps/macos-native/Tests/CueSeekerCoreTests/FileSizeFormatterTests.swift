import XCTest
@testable import CueSeekerCore

final class FileSizeFormatterTests: XCTestCase {
    func testZeroAndNegativeBytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 0), "0 B")
        XCTAssertEqual(FileSizeFormatter.format(bytes: -10), "0 B")
    }

    func testBytesBelow1024() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1), "1 B")
        XCTAssertEqual(FileSizeFormatter.format(bytes: 512), "512 B")
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1023), "1023 B")
    }

    func testKilobytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1024), "1.00 KB")
        // 102.35 KB = 102.35 * 1024 = 104806.4 -> 104806 bytes
        XCTAssertEqual(FileSizeFormatter.format(bytes: 104806), "102.35 KB")
    }

    func testMegabytes() {
        // 1 MB = 1024 * 1024 = 1048576
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1048576), "1.00 MB")
        // 15.5 MB = 15.5 * 1024 * 1024 = 16252928
        XCTAssertEqual(FileSizeFormatter.format(bytes: 16252928), "15.50 MB")
    }

    func testGigabytes() {
        // 1.43 GB = 1.43 * 1024 * 1024 * 1024 = 1535451791.36 -> 1535451791
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1535451791), "1.43 GB")
        // 2.15 GB = 2.15 * 1024 * 1024 * 1024 = 2308552458.24 -> 2308552458
        XCTAssertEqual(FileSizeFormatter.format(bytes: 2308552458), "2.15 GB")
    }
}
