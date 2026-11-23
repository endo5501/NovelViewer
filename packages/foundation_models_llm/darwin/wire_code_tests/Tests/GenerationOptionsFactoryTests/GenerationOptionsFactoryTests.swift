import FoundationModels
import XCTest

@testable import GenerationOptionsFactory

/// The options a generation request is made with. Building them must not go
/// through a deprecated initializer, which the target's warnings-as-errors
/// setting enforces; these tests hold what the options carry to what Dart
/// asked for.
final class GenerationOptionsFactoryTests: XCTestCase {
  func testGreedyIsRequestedAsGreedySampling() {
    let options = GenerationOptionsFactory.options(sampling: "greedy", maximumResponseTokens: nil)
    XCTAssertEqual(options.samplingMode, .greedy)
  }

  func testNoNameLeavesTheFrameworkItsDefault() {
    let options = GenerationOptionsFactory.options(sampling: nil, maximumResponseTokens: nil)
    XCTAssertNil(options.samplingMode)
  }

  func testAnUnknownNameIsReadAsNoName() {
    let options = GenerationOptionsFactory.options(sampling: "nucleus", maximumResponseTokens: nil)
    XCTAssertNil(options.samplingMode)
  }

  func testTheResponseCapIsCarriedAsGiven() {
    let options = GenerationOptionsFactory.options(sampling: nil, maximumResponseTokens: 512)
    XCTAssertEqual(options.maximumResponseTokens, 512)
  }

  func testNoResponseCapIsCarriedAsNone() {
    let options = GenerationOptionsFactory.options(sampling: "greedy", maximumResponseTokens: nil)
    XCTAssertNil(options.maximumResponseTokens)
  }
}
