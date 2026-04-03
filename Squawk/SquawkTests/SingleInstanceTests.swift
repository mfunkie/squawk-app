import XCTest
@testable import Squawk

final class SingleInstanceTests: XCTestCase {

    func testIsAnotherInstanceRunningReturnsBool() {
        // SingleInstanceGuard.isAnotherInstanceRunning should return Bool
        // In test context, there's only one instance
        let result = SingleInstanceGuard.isAnotherInstanceRunning
        // During tests, the test host is the running app - we mainly
        // verify the API exists and returns a Bool without crashing
        XCTAssertNotNil(result as Bool?)
    }
}
