import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_delete/data/novel_delete_service.dart';
import 'package:novel_viewer/features/novel_delete/providers/novel_delete_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:novel_viewer/features/novel_reference/providers/novel_reference_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _Dir extends CurrentDirectoryNotifier {
  @override
  String? build() => '/library';
}

class _RecordingDelete extends Fake implements NovelDeleteService {
  final deleted = <String>[];
  @override
  Future<void> delete(String folderName, String folderPath) async =>
      deleted.add(folderName);
}

void main() {
  testWidgets('deleting a novel re-reads the reference-source relations', (
    tester,
  ) async {
    var builds = 0;
    final deleteService = _RecordingDelete();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDirectoryProvider.overrideWith(_Dir.new),
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith(
            (ref) => [
              NovelMetadata(
                siteType: 'narou',
                novelId: 'narou_n1',
                title: 'テスト小説',
                url: 'https://example.com/n1',
                folderName: 'narou_n1',
                episodeCount: 1,
                downloadedAt: DateTime(2024, 1, 1),
              ),
            ],
          ),
          novelDeleteServiceProvider.overrideWith((ref) async => deleteService),
          directoryContentsProvider.overrideWith(
            (ref) async => const DirectoryContents(
              files: [],
              subdirectories: [
                DirectoryEntry(
                  name: 'narou_n1',
                  path: '/library/narou_n1',
                  displayName: 'テスト小説',
                ),
              ],
            ),
          ),
          novelReferenceRelationsProvider.overrideWith((ref) async {
            builds++;
            return const <ReferenceRelation>[];
          }),
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
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FileBrowserPanel)),
    );
    // Something holding the relations, as an open dialog would.
    final sub = container.listen(novelReferenceRelationsProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pumpAndSettle();
    final before = builds;

    await tester.tapAt(
      tester.getCenter(find.text('テスト小説')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('削除')),
    );
    await tester.pumpAndSettle();

    expect(deleteService.deleted, ['narou_n1']);
    expect(builds, greaterThan(before));
  });
}
