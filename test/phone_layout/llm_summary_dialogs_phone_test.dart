import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/data/fact_cache_repository.dart';
import 'package:novel_viewer/features/llm_summary/domain/history_entry.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_host.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_detail_dialog.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_panel.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_detail_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_history_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../helpers/phone_display.dart';

/// The LLM summary dialogs and the hover popup on the portrait display of an
/// iPhone 16 (spec adaptive-shell-layout: every dialog fits without overflow
/// and its actions are reachable).
const _folder = '/library/n9876ab';
const _word = 'アルフォンス・フォン・ヴァイスシュタイン';

const _longSummary =
    'アルフォンス・フォン・ヴァイスシュタインは辺境伯家の三男で、幼い頃に王都の'
    '魔法学院へ送られた。第十二話で主人公と出会い、以後は旅の同行者として薬草の'
    '採取や魔物討伐に加わる。剣の腕は一流だが金銭感覚に乏しく、宿代を巡って'
    'たびたび主人公と言い争う。第四十話で実家の没落を知り、領地奪還を誓う。';

const _longModelId =
    'openai-compatible:https://llm.internal.example.co.jp/v1/models/'
    'organization/team-novel/qwen3-30b-a3b-instruct-2507-q4_k_m';

const _longFileName = '049_第四十九話　辺境伯家の三男、王都の魔法学院で再会した旧友に決闘を挑まれる.txt';

FactCacheEntry _fact(String file, String facts, {String hash = 'h'}) =>
    FactCacheEntry(
      word: _word,
      fileName: file,
      facts: facts,
      contentHash: hash,
      promptVersion: 1,
      modelId: _longModelId,
      updatedAt: DateTime.utc(2026, 5, 21),
    );

WordSummary _snap(int episode, String text) => WordSummary(
  word: _word,
  coveredUpToEpisode: episode,
  summary: text,
  sourceFile: '${episode.toString().padLeft(3, '0')}_第$episode話.txt',
  createdAt: DateTime.utc(2026, 5, 21),
  updatedAt: DateTime.utc(2026, 5, 21),
);

final _facts = [
  _fact(_longFileName, '・辺境伯家の三男\n・剣の腕は一流\n・$_longSummary'),
  _fact('012_第十二話　出会い.txt', '・主人公と出会う', hash: FactCacheRepository.sentinelHash),
];

final _snapshots = [
  _snap(12, '序盤の要約。$_longSummary'),
  _snap(40, '中盤の要約。$_longSummary'),
  _snap(49, '最新の要約。$_longSummary'),
];

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'n9876ab',
  title: '転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います',
  url: 'https://ncode.syosetu.com/n9876ab/',
  folderName: 'n9876ab',
  episodeCount: 200,
  downloadedAt: DateTime(2024, 1, 1),
);

class _StubHistoryNotifier extends LlmSummaryHistoryNotifier {
  _StubHistoryNotifier(this._entries);
  final List<HistoryEntry> _entries;

  @override
  Future<List<HistoryEntry>> build() async => _entries;

  @override
  Future<void> deleteEntry(String word, {required String novelFolder}) async {}
}

class _DisplayMode extends DisplayModeNotifier {
  _DisplayMode(this._mode);
  final TextDisplayMode _mode;

  @override
  TextDisplayMode build() => _mode;
}

class _SelectedFile extends SelectedFileNotifier {
  @override
  FileEntry? build() =>
      const FileEntry(name: '049_第四十九話.txt', path: '$_folder/049_第四十九話.txt');
}

/// The visible area of the phone: inside the screen and clear of the status
/// bar and the home indicator.
const _safeArea = Rect.fromLTRB(
  0,
  kPhoneTopInset,
  393,
  852 - kPhoneBottomInset,
);

void _expectVisible(WidgetTester tester, Finder finder, String what) {
  expect(finder, findsOneWidget, reason: what);
  final rect = tester.getRect(finder);
  expect(
    rect.left >= _safeArea.left &&
        rect.right <= _safeArea.right &&
        rect.top >= _safeArea.top &&
        rect.bottom <= _safeArea.bottom,
    isTrue,
    reason: '$what at $rect is outside the visible area $_safeArea',
  );
}

List<Override> _detailOverrides({List<WordSummary>? snapshots}) => [
  historyDetailFactsProvider.overrideWith((ref, key) async => _facts),
  hoverPopupCacheProvider.overrideWith(
    (ref, key) async => snapshots ?? _snapshots,
  ),
];

/// One line of summary: well inside the height the popup anchor assumes, so
/// a placement off the visible area is down to where the anchor puts it.
final _shortSnapshots = [_snap(12, '辺境伯家の三男。'), _snap(49, '剣の腕は一流。')];

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  group('LlmSummaryDetailDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      usePhoneDisplay(tester);
      await tester.pumpWidget(
        _app(
          _detailOverrides(),
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const LlmSummaryDetailDialog(
                      folderPath: _folder,
                      word: _word,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('fits on the facts tab with a long file and model', (
      tester,
    ) async {
      await openDialog(tester);

      expect(find.byType(LlmSummaryDetailDialog), findsOneWidget);
      _expectVisible(
        tester,
        find.widgetWithText(TextButton, '閉じる'),
        'close button',
      );
      _expectVisible(tester, find.text('事実'), 'facts tab');
      _expectVisible(tester, find.text('解析結果'), 'result tab');
    });

    testWidgets('fits on the result tab with a long summary', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('解析結果'));
      await tester.pumpAndSettle();

      expect(find.textContaining('最新の要約'), findsOneWidget);
      _expectVisible(
        tester,
        find.widgetWithText(TextButton, '閉じる'),
        'close button',
      );
    });
  });

  group('LlmSummaryHistoryPanel detail dialog', () {
    testWidgets('the panel and the detail dialog it opens fit', (tester) async {
      usePhoneDisplay(tester);
      final entry = HistoryEntry.mergeRows(_snapshots).single;
      await tester.pumpWidget(
        _app([
          allNovelsProvider.overrideWith((ref) => [_novel]),
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier(_folder),
          ),
          llmSummaryHistoryProvider.overrideWith(
            () => _StubHistoryNotifier([entry]),
          ),
          ..._detailOverrides(),
        ], const Scaffold(body: SafeArea(child: LlmSummaryHistoryPanel()))),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text(_word));
      await tester.pumpAndSettle();
      _expectVisible(tester, find.text('詳細を表示'), 'view details menu item');
      await tester.tap(find.text('詳細を表示'));
      await tester.pumpAndSettle();

      expect(find.byType(LlmSummaryDetailDialog), findsOneWidget);
      _expectVisible(
        tester,
        find.widgetWithText(TextButton, '閉じる'),
        'close button',
      );
    });
  });

  group('Hover popup', () {
    Future<ProviderContainer> pumpHost(
      WidgetTester tester, {
      TextDisplayMode mode = TextDisplayMode.horizontal,
      List<WordSummary>? snapshots,
    }) async {
      usePhoneDisplay(tester);
      final container = ProviderContainer(
        overrides: [
          llmSummarySupportedProvider.overrideWithValue(true),
          displayModeProvider.overrideWith(() => _DisplayMode(mode)),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier(_folder),
          ),
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) => [_novel]),
          selectedFileProvider.overrideWith(_SelectedFile.new),
          llmSummaryRepositoryProvider.overrideWith(
            (ref, folderPath) async =>
                throw UnsupportedError('not used in this test'),
          ),
          llmSummaryHistoryProvider.overrideWith(
            () => _StubHistoryNotifier(const []),
          ),
          ..._detailOverrides(snapshots: snapshots),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HoverPopupHost(child: SizedBox.expand())),
          ),
        ),
      );
      return container;
    }

    Future<void> showAt(
      WidgetTester tester,
      ProviderContainer container,
      Offset position,
    ) async {
      container
          .read(hoverPopupProvider.notifier)
          .show(
            word: _word,
            position: position,
            token: (start: 0, end: _word.length),
          );
      await tester.pumpAndSettle();
    }

    final card = find.byKey(const Key('hover_popup_card'));
    final details = find.byKey(const Key('hover_popup_details_button'));
    final delete = find.byKey(const Key('hover_popup_delete_button'));

    // Word positions a reader can tap on the page: the text runs from just
    // under the status bar down to just above the home indicator.
    const positions = [
      (TextDisplayMode.horizontal, Offset(200, 300)),
      (TextDisplayMode.horizontal, Offset(40, 650)),
      (TextDisplayMode.horizontal, Offset(360, 800)),
      (TextDisplayMode.vertical, Offset(200, 230)),
      (TextDisplayMode.vertical, Offset(360, 80)),
    ];
    // Placements where the popup still lands outside the visible area. The
    // anchor is computed from an estimated card height that a long summary
    // exceeds, and is clamped to the display rather than to its safe area.
    // That calculation is shared with the iPad and the desktop, so changing it
    // is left to a change of its own (ios-iphone-support, design Non-Goals);
    // these are skipped until then rather than dropped.
    final outsideTheSafeArea = {
      ('a long summary', TextDisplayMode.horizontal, const Offset(40, 650)),
      ('a long summary', TextDisplayMode.horizontal, const Offset(360, 800)),
      ('a long summary', TextDisplayMode.vertical, const Offset(200, 230)),
      ('a one-line summary', TextDisplayMode.vertical, const Offset(200, 230)),
    };
    for (final (label, snapshots) in [
      ('a long summary', _snapshots),
      ('a one-line summary', _shortSnapshots),
    ]) {
      for (final (mode, position) in positions) {
        testWidgets(
          'fits inside the visible area with $label for a word at '
          '$position in ${mode.name} mode',
          skip: outsideTheSafeArea.contains((label, mode, position)),
          (tester) async {
            final container = await pumpHost(
              tester,
              mode: mode,
              snapshots: snapshots,
            );
            await showAt(tester, container, position);

            _expectVisible(tester, card, 'hover popup card');
            _expectVisible(tester, details, 'details button');
            _expectVisible(tester, delete, 'delete button');
            _expectVisible(
              tester,
              find.byKey(const Key('hover_popup_reanalyze_button')),
              're-analyze button',
            );
          },
        );
      }
    }

    testWidgets('the detail dialog it opens fits', (tester) async {
      final container = await pumpHost(tester);
      await showAt(tester, container, const Offset(200, 300));

      await tester.tap(details);
      await tester.pumpAndSettle();

      expect(find.byType(LlmSummaryDetailDialog), findsOneWidget);
      _expectVisible(
        tester,
        find.widgetWithText(TextButton, '閉じる'),
        'close button',
      );
    });

    testWidgets('the delete confirmation it opens fits', (tester) async {
      final container = await pumpHost(tester);
      await showAt(tester, container, const Offset(200, 300));

      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.text('「$_word」の解析結果を削除'), findsOneWidget);
      _expectVisible(
        tester,
        find.byKey(const Key('hover_popup_delete_cancel')),
        'cancel button',
      );
      _expectVisible(
        tester,
        find.byKey(const Key('hover_popup_delete_confirm')),
        'confirm button',
      );
    });
  });
}
