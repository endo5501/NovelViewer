enum TtsEngineType {
  qwen3(label: 'Qwen3-TTS'),
  piper(label: 'Piper');

  const TtsEngineType({required this.label});

  final String label;
}
