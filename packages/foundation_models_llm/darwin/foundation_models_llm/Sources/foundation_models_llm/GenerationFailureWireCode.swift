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

  /// The surface that replaces it from 27.0. On a system carrying it every
  /// failure arrives through it, not only the ones it added, so each case
  /// here names the code its counterpart names above.
  ///
  /// It has no case for a response that would not parse. Where it reports,
  /// the framework ends an answer that ran out of budget by closing it rather
  /// than by failing, so there is nothing left to report — which is why the
  /// same overrun that fails on iPadOS 26.6.2 is silently truncated on
  /// macOS 27.
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
  @available(iOS 26.0, macOS 26.0, *)
  static func ofAnyError(_ error: Error) -> String? {
    if #available(iOS 27.0, macOS 27.0, *), let e = error as? LanguageModelError {
      return of(e)
    }
    if let e = error as? LanguageModelSession.GenerationError {
      return of(e)
    }
    return nil
  }
}
