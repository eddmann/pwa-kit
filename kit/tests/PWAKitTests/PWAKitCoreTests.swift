@testable import PWAKitApp
import XCTest

final class PWAKitCoreTests: XCTestCase {
    func testVersionIsDefined() {
        XCTAssertFalse(PWAKitCore.version.isEmpty)
    }
}
