/// How the on-device model picks its next token.
///
/// Exposed because the choice is not a matter of taste here. Generation that
/// is not constrained by a schema falls into repeating a sentence until the
/// response cap cuts the answer off mid-object, which reaches the caller as a
/// response that will not parse. Pinning the sampling removes that.
///
/// Only the one mode is named, because it is the only one the application has
/// a reason to ask for. Everything else is expressed by naming none, which
/// leaves the framework its own default rather than this package guessing at
/// what that default currently is.
enum OnDeviceSampling {
  /// Always take the most likely token.
  greedy;

  /// The name the native side reads.
  ///
  /// The enum's own name, as the availability answer does it in the other
  /// direction. Opaque on both sides: the native side matches it or ignores
  /// it, and an unmatched name leaves the framework's default in place, which
  /// is the same thing naming no mode does.
  String get wireName => name;
}
