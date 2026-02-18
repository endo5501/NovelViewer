import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';

void main() {
  group('determineStartOffset', () {
    const text = 'はじめの文。次の文章です。最後の一文。';

    test('returns selected text offset when selectedText is found', () {
      final offset = determineStartOffset(
        text: text,
        selectedText: '次の文章です。',
      );
      expect(offset, text.indexOf('次の文章です。'));
    });

    test('returns viewStartCharOffset when selectedText is null', () {
      final offset = determineStartOffset(
        text: text,
        viewStartCharOffset: 10,
      );
      expect(offset, 10);
    });

    test('returns viewStartCharOffset when selectedText is empty', () {
      final offset = determineStartOffset(
        text: text,
        selectedText: '',
        viewStartCharOffset: 5,
      );
      expect(offset, 5);
    });

    test('returns viewStartCharOffset when selectedText is not found', () {
      final offset = determineStartOffset(
        text: text,
        selectedText: '存在しないテキスト',
        viewStartCharOffset: 8,
      );
      expect(offset, 8);
    });

    test('returns 0 when no selectedText and no viewStartCharOffset', () {
      final offset = determineStartOffset(text: text);
      expect(offset, 0);
    });

    test('finds first occurrence of selectedText', () {
      const repeatingText = 'テスト文。テスト文。別の文。';
      final offset = determineStartOffset(
        text: repeatingText,
        selectedText: 'テスト文。',
      );
      // Should return first occurrence
      expect(offset, 0);
    });
  });
}
