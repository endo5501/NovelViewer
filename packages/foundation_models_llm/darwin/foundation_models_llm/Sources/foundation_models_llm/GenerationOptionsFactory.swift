import FoundationModels

/// The options a generation request is made with, from what Dart asked for.
///
/// Kept apart from the plugin, and free of any Flutter import, for the same
/// reason `GenerationFailureWireCode` is: the plugin's own package cannot be
/// built outside a Flutter build, and this file can.
@available(iOS 26.0, macOS 26.0, *)
enum GenerationOptionsFactory {
  /// The options for one request: the sampling mode Dart named, and the
  /// response cap it set, if any.
  static func options(sampling: String?, maximumResponseTokens: Int?) -> GenerationOptions {
    GenerationOptions(
      samplingMode: samplingMode(named: sampling),
      maximumResponseTokens: maximumResponseTokens)
  }

  /// The sampling mode Dart named, or nil to leave the framework its default.
  ///
  /// A name this version does not know is read as no name at all, for the same
  /// reason Dart reads an availability answer it does not know as "unknown"
  /// rather than throwing: a sampling mode is a preference, and failing a
  /// generation over one would turn a preference into a requirement.
  static func samplingMode(named name: String?) -> GenerationOptions.SamplingMode? {
    switch name {
    case "greedy": return .greedy
    default: return nil
    }
  }
}
