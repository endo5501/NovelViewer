class TtsRefWavResolver {
  TtsRefWavResolver._();

  /// Maps the stored ref_wav_path tri-state to an effective reference WAV path.
  ///
  /// - `null` storedPath → return [fallbackPath]
  /// - empty storedPath → return `null` (explicit "no reference")
  /// - non-empty storedPath → return [resolver]\([storedPath]\) when supplied,
  ///   otherwise return [storedPath] as-is
  static String? resolve({
    required String? storedPath,
    required String? fallbackPath,
    String Function(String storedPath)? resolver,
  }) {
    if (storedPath == null) return fallbackPath;
    if (storedPath.isEmpty) return null;
    return resolver != null ? resolver(storedPath) : storedPath;
  }
}
