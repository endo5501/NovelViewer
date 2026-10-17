enum TtsEngineType {
  qwen3(label: 'Qwen3-TTS', usesReferenceVoice: true),
  piper(label: 'Piper', usesReferenceVoice: false),
  irodori(label: 'Irodori-TTS', usesReferenceVoice: true);

  const TtsEngineType({required this.label, required this.usesReferenceVoice});

  final String label;

  /// Whether the engine synthesizes from a reference voice. Piper speaks in
  /// its model's own voice, so a reference voice — global or per segment —
  /// has no effect on it.
  final bool usesReferenceVoice;
}
