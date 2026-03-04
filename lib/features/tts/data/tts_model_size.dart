enum TtsModelSize {
  small(dirName: '0.6b', modelFileName: 'qwen3-tts-0.6b-f16.gguf', label: '高速'),
  large(dirName: '1.7b', modelFileName: 'qwen3-tts-1.7b-f16.gguf', label: '高精度');

  const TtsModelSize({
    required this.dirName,
    required this.modelFileName,
    required this.label,
  });

  final String dirName;
  final String modelFileName;
  final String label;
}
