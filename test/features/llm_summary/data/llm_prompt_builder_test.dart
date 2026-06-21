import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';

void main() {
  group('LlmPromptBuilder', () {
    group('buildFactExtractionPrompt', () {
      test('contains term and context', () {
        final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'アリス',
          contextChunk: 'アリスは冒険に出た。\n---\nアリスが戻ってきた。',
        );

        expect(prompt, contains('<term>アリス</term>'));
        expect(prompt, contains('<context>'));
        expect(prompt, contains('アリスは冒険に出た。'));
        expect(prompt, contains('アリスが戻ってきた。'));
        expect(prompt, contains('{"facts":'));
      });

      test('instructs to extract facts as bulleted list', () {
        final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'テスト',
          contextChunk: 'テストの文脈',
        );

        expect(prompt, contains('箇条書き'));
      });

      test('handles empty context', () {
        final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'アリス',
          contextChunk: '',
        );

        expect(prompt, contains('<term>アリス</term>'));
        expect(prompt, contains('<context>'));
      });

      test('instructs output language for en/zh', () {
        final en = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'アリス',
          contextChunk: 'アリスは冒険に出た。',
          language: 'en',
        );
        final zh = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'アリス',
          contextChunk: 'アリスは冒険に出た。',
          language: 'zh',
        );

        expect(en, contains('English'));
        expect(zh, contains('Chinese'));
      });

      test('defaults to Japanese output when language omitted', () {
        final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'アリス',
          contextChunk: 'アリスは冒険に出た。',
        );

        expect(prompt, contains('Japanese'));
      });

      test('instructs to keep proper nouns in original language', () {
        final prompt = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'アリス',
          contextChunk: 'アリスは冒険に出た。',
          language: 'en',
        );

        expect(prompt, contains('固有名詞'));
        expect(prompt, contains('原語'));
      });
    });

    group('buildFinalSummaryPrompt', () {
      test('contains term and facts', () {
        final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
          word: '聖印',
          facts: '- 騎士に与えられる印章\n- 神聖な力を持つ',
        );

        expect(prompt, contains('<term>聖印</term>'));
        expect(prompt, contains('<facts>'));
        expect(prompt, contains('騎士に与えられる印章'));
        expect(prompt, contains('神聖な力を持つ'));
        expect(prompt, contains('{"summary":'));
      });

      test('instructs to generate 1-2 sentence summary', () {
        final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
          word: 'テスト',
          facts: '- 事実1',
        );

        expect(prompt, contains('1〜2文'));
      });

      test('instructs output language for en/zh', () {
        final en = LlmPromptBuilder.buildFinalSummaryPrompt(
          word: '聖印',
          facts: '- 騎士に与えられる印章',
          language: 'en',
        );
        final zh = LlmPromptBuilder.buildFinalSummaryPrompt(
          word: '聖印',
          facts: '- 騎士に与えられる印章',
          language: 'zh',
        );

        expect(en, contains('English'));
        expect(zh, contains('Chinese'));
      });

      test('defaults to Japanese output when language omitted', () {
        final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
          word: '聖印',
          facts: '- 騎士に与えられる印章',
        );

        expect(prompt, contains('Japanese'));
      });

      test('instructs to keep proper nouns in original language', () {
        final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
          word: '聖印',
          facts: '- アリスが所持する印章',
          language: 'en',
        );

        expect(prompt, contains('固有名詞'));
        expect(prompt, contains('原語'));
      });
    });
  });
}
