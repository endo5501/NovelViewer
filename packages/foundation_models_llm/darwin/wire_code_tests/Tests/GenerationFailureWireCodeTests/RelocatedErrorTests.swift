import FoundationModels
import XCTest

@testable import GenerationFailureWireCode

/// Three of the deprecated surface's cases did not move to
/// `LanguageModelError`. The SDK's deprecation notes send each somewhere of
/// its own, and each has to keep the code its deprecated case had, or it
/// reaches Dart as unknown and is retried whether or not it can change.
@available(iOS 27.0, macOS 27.0, *)
final class RelocatedErrorTests: XCTestCase {
  func testAssetsUnavailableKeepsItsCode() {
    // Retrying cannot bring the model's files onto the device.
    let error: Error = SystemLanguageModel.Error.assetsUnavailable(
      .init(debugDescription: "test"))
    XCTAssertEqual(GenerationFailureWireCode.ofAnyError(error), "assetsUnavailable")
  }

  func testParsingErrorKeepsTheDecodingCode() {
    // The replacement for a response that would not parse against its schema.
    let error: Error = GeneratedContent.ParsingError(
      rawContent: "{\"facts\": \"- cut", debugDescription: "test")
    XCTAssertEqual(GenerationFailureWireCode.ofAnyError(error), "decodingFailure")
  }

  func testConcurrentRequestsKeepsItsCode() {
    let error: Error = LanguageModelSession.Error.concurrentRequests
    XCTAssertEqual(GenerationFailureWireCode.ofAnyError(error), "concurrentRequests")
  }

  func testTranscriptMutationStaysUnnamed() {
    // The same type's other case. Each request starts a fresh session, so
    // this cannot happen here, and no cause Dart knows describes it.
    let error: Error = LanguageModelSession.Error.transcriptMutationWhileResponding
    XCTAssertEqual(GenerationFailureWireCode.ofAnyError(error), "unknown")
  }
}
