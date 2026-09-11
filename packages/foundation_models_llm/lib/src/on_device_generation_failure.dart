/// Why a generation request against the on-device model did not produce text.
///
/// The causes are kept apart because they mean different things for the run.
/// A refusal is about the text that was sent and says nothing about the next
/// file; an overflow is a mistake in how much was sent; rate limiting will
/// pass. Collapsing them would leave a reader unable to tell a refusal from
/// the model being out of reach.
enum OnDeviceGenerationFailure {
  /// The model's safety guardrails refused the content. Expected to happen on
  /// a novel carrying violent or sexual description, and not a defect.
  guardrailViolation,

  /// The prompt and the response together did not fit the model's window.
  contextWindowExceeded,

  /// The system declined to run the request for now.
  rateLimited,

  /// The model does not work in the language it was asked for.
  unsupportedLanguage,

  /// The model's own files are not on the device.
  assetsUnavailable,

  /// The model could not be reached at all. Distinct from a refusal: nothing
  /// was judged about the content.
  modelUnavailable,

  /// The native side failed in a way this version does not recognise.
  unknown;

  /// Reads the error code the native side reports.
  static OnDeviceGenerationFailure fromWireCode(String? code) => switch (code) {
    // The framework reports a guardrail block and the model's own refusal
    // as separate cases. Both mean the text was refused, so they arrive
    // here as one reason while the native code keeps them apart in its
    // message.
    'guardrailViolation' ||
    'refusal' => OnDeviceGenerationFailure.guardrailViolation,
    'exceededContextWindowSize' =>
      OnDeviceGenerationFailure.contextWindowExceeded,
    'rateLimited' => OnDeviceGenerationFailure.rateLimited,
    'unsupportedLanguageOrLocale' =>
      OnDeviceGenerationFailure.unsupportedLanguage,
    'assetsUnavailable' => OnDeviceGenerationFailure.assetsUnavailable,
    'modelUnavailable' => OnDeviceGenerationFailure.modelUnavailable,
    _ => OnDeviceGenerationFailure.unknown,
  };
}

/// Thrown when the on-device model produces no usable text.
class OnDeviceGenerationException implements Exception {
  const OnDeviceGenerationException(this.reason, {this.detail});

  /// What went wrong, in terms a caller can act on.
  final OnDeviceGenerationFailure reason;

  /// Whatever the native side said, kept for the log. Never shown to the
  /// reader as it stands: the reader-facing wording comes from [reason].
  final String? detail;

  @override
  String toString() => detail == null
      ? 'OnDeviceGenerationException(${reason.name})'
      : 'OnDeviceGenerationException(${reason.name}: $detail)';
}
