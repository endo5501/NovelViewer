import FoundationModels

/// The error codes Dart reads back, and the framework failures they name.
///
/// Kept apart from the plugin, and free of any Flutter import, because this
/// is the one piece of the native side that is pure enough to be tested on
/// its own: the plugin's own package cannot be built outside a Flutter build,
/// and this file can.
enum GenerationFailureWireCode {
  /// The code for a failure this file cannot name.
  static let unknown = "unknown"

  /// The deprecated surface, still the one that reports on a system that
  /// predates the replacement.
  ///
  /// A guardrail block and the model's own refusal are reported separately by
  /// the framework and kept separate here, so a log says which happened; Dart
  /// reads both as the text having been refused.
  @available(iOS 26.0, macOS 26.0, *)
  static func of(_ error: LanguageModelSession.GenerationError) -> String {
    switch error {
    case .exceededContextWindowSize: return "exceededContextWindowSize"
    case .assetsUnavailable: return "assetsUnavailable"
    case .guardrailViolation: return "guardrailViolation"
    case .refusal: return "refusal"
    case .unsupportedGuide: return "unsupportedGuide"
    case .unsupportedLanguageOrLocale: return "unsupportedLanguageOrLocale"
    case .decodingFailure: return "decodingFailure"
    case .rateLimited: return "rateLimited"
    case .concurrentRequests: return "concurrentRequests"
    @unknown default: return unknown
    }
  }

  /// The type that replaces it from 27.0 for most of its cases. Each case
  /// here names the code its deprecated counterpart names above.
  ///
  /// Three deprecated cases went elsewhere — the model's assets, a response
  /// that would not parse, and a concurrent request each have a type of
  /// their own — and `ofAnyError` reads those.
  @available(iOS 27.0, macOS 27.0, *)
  static func of(_ error: LanguageModelError) -> String {
    switch error {
    case .contextSizeExceeded: return "exceededContextWindowSize"
    case .rateLimited: return "rateLimited"
    case .guardrailViolation: return "guardrailViolation"
    case .refusal: return "refusal"
    case .unsupportedCapability: return "unsupportedCapability"
    case .unsupportedTranscriptContent: return "unsupportedTranscriptContent"
    case .unsupportedGenerationGuide: return "unsupportedGenerationGuide"
    case .unsupportedLanguageOrLocale: return "unsupportedLanguageOrLocale"
    case .timeout: return "timeout"
    @unknown default: return unknown
    }
  }

  /// The code for whatever was thrown, found through whichever surface
  /// reported it, or nil where neither did. The caller decides what to say
  /// about an error that is not the framework's; forcing it into a named
  /// cause would report it as something it is not.
  ///
  /// From 27.0 the deprecated type's cases are reported through four types,
  /// not one: the SDK's deprecation notes send the model's assets to
  /// `SystemLanguageModel.Error`, a response that would not parse to
  /// `GeneratedContent.ParsingError`, and a concurrent request to
  /// `LanguageModelSession.Error`, and everything else to
  /// `LanguageModelError`. Each keeps the code its deprecated case had.
  @available(iOS 26.0, macOS 26.0, *)
  static func ofAnyError(_ error: Error) -> String? {
    if #available(iOS 27.0, macOS 27.0, *), let code = ofReplacement(error) {
      return code
    }
    if let e = error as? LanguageModelSession.GenerationError {
      return of(e)
    }
    return nil
  }

  @available(iOS 27.0, macOS 27.0, *)
  private static func ofReplacement(_ error: Error) -> String? {
    if let e = error as? LanguageModelError {
      return of(e)
    }
    if let e = error as? SystemLanguageModel.Error {
      switch e {
      case .assetsUnavailable: return "assetsUnavailable"
      @unknown default: return unknown
      }
    }
    if error is GeneratedContent.ParsingError {
      return "decodingFailure"
    }
    if let e = error as? LanguageModelSession.Error {
      switch e {
      case .concurrentRequests: return "concurrentRequests"
      // Each request starts a fresh session, so its transcript cannot be
      // changed while it responds, and no cause Dart knows describes it.
      case .transcriptMutationWhileResponding: return unknown
      @unknown default: return unknown
      }
    }
    return nil
  }
}
