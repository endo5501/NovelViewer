import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';

class _StubHistory extends LlmSummaryHistoryNotifier {
  final List<HistoryEntry> _entries;
  _StubHistory(this._entries);

  @override
  Future<List<HistoryEntry>> build() async => _entries;
}

HistoryEntry _entry({
  required String folder,
  required String word,
  required int episode,
}) {
  final snap = WordSummary(
    folderName: folder,
    word: word,
    coveredUpToEpisode: episode,
    summary: 's',
    sourceFile: '$episode.txt',
    createdAt: DateTime.utc(2026, 5, 21),
    updatedAt: DateTime.utc(2026, 5, 21),
  );
  return HistoryEntry.mergeRows([snap]).single;
}

void main() {
  test('returns empty map when no history entries exist', () async {
    final container = ProviderContainer(
      overrides: [
        llmSummaryHistoryProvider.overrideWith(() => _StubHistory(const [])),
      ],
    );
    addTearDown(container.dispose);

    await container.read(llmSummaryHistoryProvider.future);

    expect(container.read(markedWordsProvider), isEmpty);
  });

  test('exposes a word -> MarkStyle.solid map derived from history entries',
      () async {
    final entries = [
      _entry(folder: 'my_novel', word: 'アリス', episode: 40),
      _entry(folder: 'my_novel', word: 'ボブ', episode: 41),
      _entry(folder: 'my_novel', word: '聖印', episode: 42),
    ];

    final container = ProviderContainer(
      overrides: [
        llmSummaryHistoryProvider.overrideWith(() => _StubHistory(entries)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(llmSummaryHistoryProvider.future);

    final marks = container.read(markedWordsProvider);
    expect(marks['アリス'], MarkStyle.solid);
    expect(marks['ボブ'], MarkStyle.solid);
    expect(marks['聖印'], MarkStyle.solid);
  });

  test('excludes words shorter than 2 characters', () async {
    final entries = [
      _entry(folder: 'my_novel', word: '光', episode: 40),
      _entry(folder: 'my_novel', word: '聖印', episode: 41),
    ];

    final container = ProviderContainer(
      overrides: [
        llmSummaryHistoryProvider.overrideWith(() => _StubHistory(entries)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(llmSummaryHistoryProvider.future);

    final marks = container.read(markedWordsProvider);
    expect(marks.containsKey('光'), isFalse);
    expect(marks['聖印'], MarkStyle.solid);
  });

  test('returns empty map while history is still loading', () async {
    final container = ProviderContainer(
      overrides: [
        llmSummaryHistoryProvider.overrideWith(() => _StubHistory(const [])),
      ],
    );
    addTearDown(container.dispose);

    final marks = container.read(markedWordsProvider);
    expect(marks, isEmpty);
  });
}
