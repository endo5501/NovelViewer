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
  static String? resolve({
    required String? storedPath,
    required String? fallbackPath,
    required String Function(String storedPath)? resolver,
  }) {
    if (storedPath == null) return fallbackPath;
    if (storedPath.isEmpty) return null;
    return resolver != null ? resolver(storedPath) : storedPath;
  }
}
