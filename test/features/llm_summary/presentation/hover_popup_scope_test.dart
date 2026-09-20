import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_host.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _MockDisplayMode extends DisplayModeNotifier {
  @override
  TextDisplayMode build() => TextDisplayMode.horizontal;
}

class _MockSelectedFile extends SelectedFileNotifier {
  _MockSelectedFile(this._initial);
  final FileEntry? _initial;
  @override
  FileEntry? build() => _initial;
}

final _otherNovel = NovelMetadata(
  siteType: 'narou',
  novelId: 'narou_n5678cd',
  title: '別の小説',
  url: 'https://ncode.syosetu.com/narou_n5678cd/',
  folderName: 'narou_n5678cd',
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

final _novel = NovelMetadata(
  siteType: 'narou',
  novelId: 'narou_n1234ab',
  title: '異世界転生物語',
  url: 'https://ncode.syosetu.com/narou_n1234ab/',
  folderName: 'narou_n1234ab',
  episodeCount: 3,
  downloadedAt: DateTime(2024, 1, 1),
);

WordSummary _snapshot() => WordSummary(
  word: 'アリス',
  coveredUpToEpisode: 1,
  summary: 'アリスの要約',
  sourceFile: '001.txt',
  createdAt: DateTime.parse('2026-05-24T10:00:00Z'),
  updatedAt: DateTime.parse('2026-05-24T10:00:00Z'),
);

ProviderContainer _containerAt(String directory) {
  return ProviderContainer(
    overrides: [
      displayModeProvider.overrideWith(_MockDisplayMode.new),
      libraryPathProvider.overrideWithValue('/library'),
      allNovelsProvider.overrideWith((ref) => [_novel]),
      currentDirectoryProvider.overrideWith(
        () => CurrentDirectoryNotifier(directory),
      ),
      selectedFileProvider.overrideWith(
        () => _MockSelectedFile(
          FileEntry(name: '001.txt', path: '$directory/001.txt'),
        ),
      ),
      // Keyed on the novel folder, which is the folder the popup must ask for.
      hoverPopupCacheProvider.overrideWith((_, _) async => [_snapshot()]),
    ],
  );
}

Future<ProviderContainer> _showPopupAt(
  WidgetTester tester,
  String directory,
) async {
  final container = _containerAt(directory);
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
  // Let allNovelsProvider settle before the popup asks for the novel folder.
  await tester.pumpAndSettle();

  container
      .read(hoverPopupProvider.notifier)
      .show(
        word: 'アリス',
        position: const Offset(100, 200),
        token: (start: 0, end: 3),
      );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('HoverPopupHost の対象フォルダ', () {
    testWidgets('整理フォルダでは popup を出さない', (tester) async {
      await _showPopupAt(tester, '/library/完結済み');

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets('ライブラリルートでは popup を出さない', (tester) async {
      await _showPopupAt(tester, '/library');

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets('小説フォルダでは小説フォルダを渡す', (tester) async {
      await _showPopupAt(tester, '/library/narou_n1234ab');

      final popup = tester.widget<HoverPopupWidget>(
        find.byType(HoverPopupWidget),
      );
      expect(popup.folderPath, '/library/narou_n1234ab');
    });

    testWidgets('小説フォルダ内のサブフォルダでは popup を出さない', (tester) async {
      await _showPopupAt(tester, '/library/narou_n1234ab/第二部');

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets('表示中にブラウザが別の小説へ移ると popup は消える', (tester) async {
      // Navigating by keyboard never sends a pointer down, so the dismissal
      // that a click would cause does not happen. A popup left behind would
      // hand the previous novel's episode number and file name to a
      // re-analysis that writes into the new one.
      final container = await _showPopupAt(tester, '/library/narou_n1234ab');
      expect(find.byType(HoverPopupWidget), findsOneWidget);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/library/narou_n5678cd');
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets('表示中にブラウザが小説の外へ出ても popup は消える', (tester) async {
      final container = await _showPopupAt(tester, '/library/narou_n1234ab');
      expect(find.byType(HoverPopupWidget), findsOneWidget);

      container
          .read(currentDirectoryProvider.notifier)
          .setDirectory('/library/完結済み');
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets('整理フォルダに入れ子の小説フォルダでは出す', (tester) async {
      await _showPopupAt(tester, '/library/完結済み/narou_n1234ab');

      final popup = tester.widget<HoverPopupWidget>(
        find.byType(HoverPopupWidget),
      );
      expect(popup.folderPath, '/library/完結済み/narou_n1234ab');
    });
  });
}
