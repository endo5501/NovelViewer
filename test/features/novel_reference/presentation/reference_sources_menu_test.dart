import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/presentation/reference_sources_dialog.dart';
import 'package:novel_viewer/features/novel_reference/providers/novel_reference_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _Dir extends CurrentDirectoryNotifier {
  @override
  String? build() => '/library';
}

NovelMetadata _novel(String folderName, String title) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: title,
  url: 'https://example.com/$folderName',
  folderName: folderName,
  episodeCount: 1,
  downloadedAt: DateTime(2024, 1, 1),
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  Future<void> pumpBrowser(WidgetTester tester, {required bool llm}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directoryContentsProvider.overrideWith(
            (ref) async => const DirectoryContents(
              files: [],
              subdirectories: [
                DirectoryEntry(
                  name: 'narou_p1',
                  path: '/library/narou_p1',
                  displayName: '第1部',
                ),
                DirectoryEntry(
                  name: 'shelf',
                  path: '/library/shelf',
                  displayName: 'shelf',
                ),
              ],
            ),
          ),
          currentDirectoryProvider.overrideWith(_Dir.new),
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) => [_novel('narou_p1', '第1部')]),
          llmSummarySupportedProvider.overrideWithValue(llm),
          novelReferenceRelationsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileBrowserPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> rightClick(WidgetTester tester, String label) async {
    final center = tester.getCenter(find.text(label));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.addPointer(location: center);
    await gesture.down(center);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a novel folder offers the reference-source settings', (
    tester,
  ) async {
    await pumpBrowser(tester, llm: true);

    await rightClick(tester, '第1部');

    expect(
      find.text(l10n.fileBrowser_referenceSourcesMenuItem),
      findsOneWidget,
    );
  });

  testWidgets('choosing it opens the dialog for that novel', (tester) async {
    await pumpBrowser(tester, llm: true);

    await rightClick(tester, '第1部');
    await tester.tap(find.text(l10n.fileBrowser_referenceSourcesMenuItem));
    await tester.pumpAndSettle();

    expect(find.byType(ReferenceSourcesDialog), findsOneWidget);
    expect(find.text(l10n.referenceSources_dialogTitle('第1部')), findsOneWidget);
  });

  testWidgets('an organizing folder does not offer it', (tester) async {
    await pumpBrowser(tester, llm: true);

    await rightClick(tester, 'shelf');

    expect(find.text(l10n.fileBrowser_referenceSourcesMenuItem), findsNothing);
  });

  testWidgets('it is not offered where LLM summary is unavailable', (
    tester,
  ) async {
    await pumpBrowser(tester, llm: false);

    await rightClick(tester, '第1部');

    expect(find.text(l10n.fileBrowser_referenceSourcesMenuItem), findsNothing);
  });
}
