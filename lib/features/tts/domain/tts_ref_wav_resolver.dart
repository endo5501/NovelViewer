import 'package:path/path.dart' as p;

class TtsRefWavResolver {
  TtsRefWavResolver._();

  /// Maps the stored ref_wav_path tri-state to an effective reference WAV path.
  ///
  /// - `null` storedPath → return [fallbackPath]
  /// - empty storedPath → return `null` (explicit "no reference")
  /// - non-empty storedPath → return [resolver]\([storedPath]\) when supplied,
  ///   otherwise return [storedPath] as-is
  ///
  /// [resolver] is required even though it is nullable: stored paths are bare
  /// file names, so omitting it silently hands a file name to the synthesis
  /// engine. Passing `null` has to be a deliberate "the stored value is already
  /// a full path" rather than something a caller can forget.
  ///
  /// [acceptedExtensions] are the reference extensions the engine reads, in
  /// lower case, or `null` for any. A stored file outside them resolves to
  /// `null`, as the voice selector shows it as none, rather than to
  /// [fallbackPath]: the segment chose its voice, and the global one is not
  /// the one chosen. It is required for the same reason [resolver] is.
  static String? resolve({
    required String? storedPath,
    required String? fallbackPath,
    required String Function(String storedPath)? resolver,
    required Set<String>? acceptedExtensions,
  }) {
    if (storedPath == null) return fallbackPath;
    if (storedPath.isEmpty) return null;
    if (acceptedExtensions != null &&
        !acceptedExtensions.contains(p.extension(storedPath).toLowerCase())) {
      return null;
    }
    return resolver != null ? resolver(storedPath) : storedPath;
  }
}
