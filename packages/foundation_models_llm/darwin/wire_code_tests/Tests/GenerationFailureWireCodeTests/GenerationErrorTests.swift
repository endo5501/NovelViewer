import FoundationModels
import XCTest

@testable import GenerationFailureWireCode

/// The deprecated surface. It still reports on a system that predates its
/// replacement — iPadOS 26.6.2 reported the refinement overrun through it as
/// a decoding failure — so its mapping must not move while the newer one is
/// added alongside it.
@available(iOS 26.0, macOS 26.0, *)
@available(macOS, deprecated: 27.0)
@available(iOS, deprecated: 27.0)
final class GenerationErrorTests: XCTestCase {
  private typealias E = LanguageModelSession.GenerationError
  private let context = E.Context(debugDescription: "test")

  func testEveryCaseKeepsItsCode() {
    let expected: [(E, String)] = [
      (.exceededContextWindowSize(context), "exceededContextWindowSize"),
      (.assetsUnavailable(context), "assetsUnavailable"),
      (.guardrailViolation(context), "guardrailViolation"),
      (.unsupportedGuide(context), "unsupportedGuide"),
      (.unsupportedLanguageOrLocale(context), "unsupportedLanguageOrLocale"),
      (.decodingFailure(context), "decodingFailure"),
      (.rateLimited(context), "rateLimited"),
      (.concurrentRequests(context), "concurrentRequests"),
      (.refusal(.init(transcriptEntries: []), context), "refusal"),
    ]
    for (error, code) in expected {
      XCTAssertEqual(GenerationFailureWireCode.of(error), code, "\(error)")
    }
  }

  func testAnyErrorFindsTheDeprecatedSurface() {
    // A system that predates the replacement reports through this surface
    // only, so the plugin's catch-all must still find it.
    let error: Error = E.decodingFailure(context)
    XCTAssertEqual(GenerationFailureWireCode.ofAnyError(error), "decodingFailure")
  }
}
