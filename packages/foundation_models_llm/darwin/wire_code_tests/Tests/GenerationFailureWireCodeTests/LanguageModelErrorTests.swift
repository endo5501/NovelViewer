import Foundation
import FoundationModels
import XCTest

@testable import GenerationFailureWireCode

/// The surface that replaces `LanguageModelSession.GenerationError` from
/// 27.0. On a system carrying it every failure arrives through it, so each of
/// its cases has to name the cause it names on the deprecated surface, or
/// that cause reaches Dart as unknown and is retried when it cannot change.
@available(iOS 27.0, macOS 27.0, *)
final class LanguageModelErrorTests: XCTestCase {
  private let why = "test"

  func testContextSizeExceededNamesTheWindow() {
    let error = LanguageModelError.contextSizeExceeded(
      .init(contextSize: 4096, tokenCount: 5000, debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "exceededContextWindowSize")
  }

  func testRateLimitedNamesRateLimiting() {
    let error = LanguageModelError.rateLimited(
      .init(resetDate: nil, debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "rateLimited")
  }

  func testGuardrailViolationNamesTheGuardrail() {
    let error = LanguageModelError.guardrailViolation(
      .init(debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "guardrailViolation")
  }

  func testRefusalNamesTheModelDeclining() {
    // Measured on macOS 26A428: the merge prompt's refusal arrived as this
    // case, and the plugin read it as unknown.
    let error = LanguageModelError.refusal(
      .init(explanation: "May contain sensitive content", debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "refusal")
  }

  func testUnsupportedCapabilityHasItsOwnCode() {
    let error = LanguageModelError.unsupportedCapability(
      .init(capability: .vision, debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "unsupportedCapability")
  }

  func testUnsupportedTranscriptContentHasItsOwnCode() {
    let error = LanguageModelError.unsupportedTranscriptContent(
      .init(unsupportedContent: [], debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "unsupportedTranscriptContent")
  }

  func testUnsupportedGenerationGuideHasItsOwnCode() {
    let error = LanguageModelError.unsupportedGenerationGuide(
      .init(schemaName: nil, debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "unsupportedGenerationGuide")
  }

  func testUnsupportedLanguageNamesTheLanguage() {
    let error = LanguageModelError.unsupportedLanguageOrLocale(
      .init(languageCode: .init("xx"), debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "unsupportedLanguageOrLocale")
  }

  func testTimeoutHasItsOwnCode() {
    let error = LanguageModelError.timeout(.init(debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.of(error), "timeout")
  }

  // The plugin catches `any Error` and has to find the surface itself.

  func testAnyErrorFindsTheNewerSurface() {
    let error: Error = LanguageModelError.refusal(
      .init(explanation: "x", debugDescription: why))
    XCTAssertEqual(GenerationFailureWireCode.ofAnyError(error), "refusal")
  }

  func testAnyErrorLeavesAForeignErrorUnnamed() {
    // Neither surface names it, so it must not be forced into a named cause.
    struct Foreign: Error {}
    XCTAssertNil(GenerationFailureWireCode.ofAnyError(Foreign()))
  }
}
