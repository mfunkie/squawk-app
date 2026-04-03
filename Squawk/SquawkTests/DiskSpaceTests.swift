import XCTest
@testable import Squawk

final class DiskSpaceTests: XCTestCase {

    func testCheckDiskSpaceReturnsBoolean() {
        // DiskSpaceChecker.hasEnoughSpace() should return a Bool
        let result = DiskSpaceChecker.hasEnoughSpace(requiredBytes: 1_000_000_000)
        // On a dev machine, we expect true (>1GB free)
        XCTAssertTrue(result)
    }

    func testCheckDiskSpaceWithZeroBytesRequired() {
        // Zero bytes required should always pass
        let result = DiskSpaceChecker.hasEnoughSpace(requiredBytes: 0)
        XCTAssertTrue(result)
    }

    func testCheckDiskSpaceWithExtremeRequirement() {
        // Requiring 100TB should fail on any normal machine
        let result = DiskSpaceChecker.hasEnoughSpace(requiredBytes: 100_000_000_000_000)
        XCTAssertFalse(result)
    }
}
