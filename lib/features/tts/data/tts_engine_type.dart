enum TtsEngineType {
  qwen3(label: 'Qwen3-TTS'),
  piper(label: 'Piper'),
  irodori(label: 'Irodori-TTS');

  const TtsEngineType({required this.label});

  final String label;
}
