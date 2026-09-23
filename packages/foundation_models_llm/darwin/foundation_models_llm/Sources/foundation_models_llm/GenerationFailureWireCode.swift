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

  @available(iOS 27.0, macOS 27.0, *)
  static func of(_ error: LanguageModelError) -> String { unknown }

  @available(iOS 26.0, macOS 26.0, *)
  static func ofAnyError(_ error: Error) -> String? { nil }
}
