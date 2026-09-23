import XCTest

@testable import GenerationFailureWireCode

final class SmokeTests: XCTestCase {
  func testTheHarnessRuns() {
    XCTAssertEqual(GenerationFailureWireCode.unknown, "unknown")
  }
}
