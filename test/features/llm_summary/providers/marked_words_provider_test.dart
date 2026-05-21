import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/marked_words_provider.dart';

class _StubHistory extends LlmSummaryHistoryNotifier {
  final List<HistoryEntry> _entries;
  _StubHistory(this._entries);

  @override
  Future<List<HistoryEntry>> build() async => _entries;
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

  test('exposes a word -> MarkStyle map derived from history entries',
      () async {
    final entries = [
      HistoryEntry(
        folderName: 'my_novel',
        word: 'アリス',
        type: HistoryEntryType.both,
        summaryPreview: 'a',
        sourceFile: '040.txt',
        updatedAt: DateTime.utc(2026, 5, 21),
      ),
      HistoryEntry(
        folderName: 'my_novel',
        word: 'ボブ',
        type: HistoryEntryType.noSpoilerOnly,
        summaryPreview: 'b',
        sourceFile: '041.txt',
        updatedAt: DateTime.utc(2026, 5, 20),
      ),
      HistoryEntry(
        folderName: 'my_novel',
        word: '聖印',
        type: HistoryEntryType.spoilerOnly,
        summaryPreview: 'c',
        sourceFile: '042.txt',
        updatedAt: DateTime.utc(2026, 5, 19),
      ),
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
    expect(marks['ボブ'], MarkStyle.dotted);
    expect(marks['聖印'], MarkStyle.solid);
  });

  test('excludes words shorter than 2 characters', () async {
    final entries = [
      HistoryEntry(
        folderName: 'my_novel',
        word: '光',
        type: HistoryEntryType.spoilerOnly,
        summaryPreview: '',
        sourceFile: '040.txt',
        updatedAt: DateTime.utc(2026, 5, 21),
      ),
      HistoryEntry(
        folderName: 'my_novel',
        word: '聖印',
        type: HistoryEntryType.spoilerOnly,
        summaryPreview: '',
        sourceFile: '041.txt',
        updatedAt: DateTime.utc(2026, 5, 20),
      ),
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

    // Read marks before awaiting history → history is in loading state.
    final marks = container.read(markedWordsProvider);
    expect(marks, isEmpty);
  });
}
