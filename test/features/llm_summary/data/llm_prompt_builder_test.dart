import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';

void main() {
  group('LlmPromptBuilder', () {
    test('buildSpoilerPrompt contains term and context', () {
      final prompt = LlmPromptBuilder.buildSpoilerPrompt(
        word: 'アリス',
        contexts: ['アリスは冒険に出た。', 'アリスが戻ってきた。'],
      );

      expect(prompt, contains('<term>アリス</term>'));
      expect(prompt, contains('<context>'));
      expect(prompt, contains('アリスは冒険に出た。'));
      expect(prompt, contains('アリスが戻ってきた。'));
      expect(prompt, contains('{"summary":'));
    });

    test('buildNoSpoilerPrompt contains no-spoiler instruction', () {
      final prompt = LlmPromptBuilder.buildNoSpoilerPrompt(
        word: 'アリス',
        contexts: ['アリスが登場した。'],
      );

      expect(prompt, contains('<term>アリス</term>'));
      expect(prompt, contains('ネタバレ'));
    });

    test('limits context to maximum 10 entries', () {
      final contexts = List.generate(15, (i) => 'コンテキスト$i');

      final prompt = LlmPromptBuilder.buildSpoilerPrompt(
        word: 'テスト',
        contexts: contexts,
      );

      expect(prompt, contains('コンテキスト0'));
      expect(prompt, contains('コンテキスト9'));
      expect(prompt, isNot(contains('コンテキスト10')));
    });

    test('handles empty context list', () {
      final prompt = LlmPromptBuilder.buildSpoilerPrompt(
        word: 'アリス',
        contexts: [],
      );

      expect(prompt, contains('<term>アリス</term>'));
      expect(prompt, contains('<context>'));
    });
  });
}
