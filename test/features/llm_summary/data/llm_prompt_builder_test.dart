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
    group('buildFactRefinementPrompt', () {
      String build({int budget = 1300, String language = 'ja'}) =>
          LlmPromptBuilder.buildFactRefinementPrompt(
            word: 'ユバール',
            facts: '- ロシエ王国の属国\n- ロシエ王国の属国である',
            maxResponseSize: budget,
            language: language,
          );

      test('contains the term and the facts it is given', () {
        final prompt = build();

        expect(prompt, contains('<term>ユバール</term>'));
        expect(prompt, contains('<facts>'));
        expect(prompt, contains('- ロシエ王国の属国である'));
      });

      test('is not the extraction prompt', () {
        // Rounds 2 and later take facts that are already extracted. Asked to
        // enumerate them, the model copies them back, and the answer grows
        // until the response cap cuts it off.
        final extraction = LlmPromptBuilder.buildFactExtractionPrompt(
          word: 'ユバール',
          contextChunk: '- ロシエ王国の属国',
        );

        expect(build(), isNot(extraction));
        expect(build(), isNot(contains('列挙')));
      });

      test('instructs merging and de-duplication', () {
        final prompt = build();

        expect(prompt, contains('統合'));
        expect(prompt, contains('重複'));
      });

      test('states a bound derived from the response budget', () {
        final bound = LlmPromptBuilder.refinementBound(1300);

        expect(build(budget: 1300), contains('$bound文字以内'));
      });

      test('keeps the bound well under the response budget', () {
        // Measured: a merge prompt asking for 400 characters was answered in
        // 342 to 464. The bound has to leave room for that overshoot.
        for (final budget in const [768, 1300, 4000]) {
          final bound = LlmPromptBuilder.refinementBound(budget);
          expect(bound, lessThanOrEqualTo(budget ~/ 2), reason: '$budget');
          expect(bound, greaterThan(0), reason: '$budget');
        }
      });

      test('follows each client\'s own budget', () {
        final small = LlmPromptBuilder.refinementBound(1400);
        final large = LlmPromptBuilder.refinementBound(4000);

        expect(small, lessThan(large));
        expect(build(budget: 1400), contains('$small文字以内'));
        expect(build(budget: 4000), contains('$large文字以内'));
      });

      test('states the same bound whichever language is requested', () {
        // Measured: the on-device model and qwen3.5 answered English and
        // Chinese requests in Japanese. A bound raised for English would be
        // filled with Japanese.
        final bound = LlmPromptBuilder.refinementBound(1300);

        for (final language in const ['ja', 'en', 'zh']) {
          expect(
            build(language: language),
            contains('$bound文字以内'),
            reason: language,
          );
        }
      });

      test('instructs output language for en/zh', () {
        expect(build(language: 'en'), contains('English'));
        expect(build(language: 'zh'), contains('Chinese'));
        expect(build(), contains('Japanese'));
      });

      test('instructs to keep proper nouns in original language', () {
        final prompt = build(language: 'en');

        expect(prompt, contains('固有名詞'));
        expect(prompt, contains('原語'));
      });

      test('asks for the facts field', () {
        expect(build(), contains('"facts"'));
      });
    });
  });
}
