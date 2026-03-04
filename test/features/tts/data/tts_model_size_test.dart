import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';

void main() {
  group('TtsModelSize', () {
    test('small has correct dirName', () {
      expect(TtsModelSize.small.dirName, '0.6b');
    });

    test('small has correct modelFileName', () {
      expect(TtsModelSize.small.modelFileName, 'qwen3-tts-0.6b-f16.gguf');
    });

    test('small has correct label', () {
      expect(TtsModelSize.small.label, '高速');
    });

    test('large has correct dirName', () {
      expect(TtsModelSize.large.dirName, '1.7b');
    });

    test('large has correct modelFileName', () {
      expect(TtsModelSize.large.modelFileName, 'qwen3-tts-1.7b-f16.gguf');
    });

    test('large has correct label', () {
      expect(TtsModelSize.large.label, '高精度');
    });

    test('has exactly two values', () {
      expect(TtsModelSize.values.length, 2);
    });
  });
}
