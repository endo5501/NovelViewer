import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/data/novel_reference_repository.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:novel_viewer/features/novel_reference/presentation/reference_sources_dialog.dart';
import 'package:novel_viewer/features/novel_reference/providers/novel_reference_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

NovelMetadata _novel(
  String folderName,
  String title, {
  String site = 'narou',
}) => NovelMetadata(
  siteType: site,
  novelId: folderName,
  title: title,
  url: 'https://example.com/$folderName',
  folderName: folderName,
  episodeCount: 1,
  downloadedAt: DateTime(2024, 1, 1),
);

final _novels = [
  _novel('part3', '第3部'),
  _novel('part2', '第2部'),
  _novel('part1', '第1部'),
  _novel('gaiden', '外伝'),
  _novel('wiki', 'Wiki 記事集', site: 'web'),
  _novel('other', '別作品'),
];

class _SlowRepository extends NovelReferenceRepository {
  _SlowRepository(super.db);

  final gate = Completer<void>();

  @override
  Future<void> replaceParents(String child, Iterable<String> parents) async {
    await gate.future;
    await super.replaceParents(child, parents);
  }
}

class _FailingRepository extends NovelReferenceRepository {
  _FailingRepository(super.db);

  @override
  Future<void> replaceParents(String child, Iterable<String> parents) async {
    throw ReferenceCycleException(child);
  }
}

void main() {
  late NovelDatabase novelDatabase;
  late NovelReferenceRepository repository;
  late AppLocalizations l10n;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    l10n = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = NovelReferenceRepository(novelDatabase);
    // part3 -> part2 -> part1, gaiden -> part3
    await repository.replaceParents('part3', ['part2']);
    await repository.replaceParents('part2', ['part1']);
    await repository.replaceParents('gaiden', ['part3']);
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    NovelReferenceRepository? repo,
  }) async {
    final container = ProviderContainer(
      overrides: [
        novelDatabaseProvider.overrideWithValue(novelDatabase),
        allNovelsProvider.overrideWith((ref) => _novels),
        if (repo != null)
          novelReferenceRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      // The database answers on the real event loop, so the relations are
      // loaded here rather than from inside a fake-async frame.
      await container.read(novelReferenceRelationsProvider.future);
      await container.read(allNovelsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ReferenceSourcesDialog(
                      folderName: 'part3',
                      title: '第3部',
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
    });
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Finder inSection(String sectionKey, Finder matching) =>
      find.descendant(of: find.byKey(Key(sectionKey)), matching: matching);

  group('ReferenceSourcesDialog', () {
    testWidgets('shows direct sources, inherited ancestors and children', (
      tester,
    ) async {
      await pumpDialog(tester);

      expect(
        find.text(l10n.referenceSources_dialogTitle('第3部')),
        findsOneWidget,
      );
      expect(
        inSection('reference_sources_direct', find.text('第2部')),
        findsOneWidget,
      );
      expect(
        inSection('reference_sources_inherited', find.text('第1部')),
        findsOneWidget,
      );
      expect(
        inSection(
          'reference_sources_inherited',
          find.text(l10n.referenceSources_via('第2部')),
        ),
        findsOneWidget,
      );
      expect(
        inSection('reference_sources_children', find.text('外伝')),
        findsOneWidget,
      );
    });

    testWidgets('cancel discards edits', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(const Key('reference_source_remove_part2')));
      await tester.pumpAndSettle();
      expect(
        inSection('reference_sources_direct', find.text('第2部')),
        findsNothing,
      );
      expect(
        inSection('reference_sources_inherited', find.text('第1部')),
        findsNothing,
        reason: 'the preview follows the edit',
      );
      await tester.tap(find.text(l10n.common_cancelButton));
      await settle(tester);

      expect((await tester.runAsync(repository.findAll))!.toSet(), {
        const ReferenceRelation(child: 'part3', parent: 'part2'),
        const ReferenceRelation(child: 'part2', parent: 'part1'),
        const ReferenceRelation(child: 'gaiden', parent: 'part3'),
      });
    });

    testWidgets('save persists an added source', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text(l10n.referenceSources_addButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wiki 記事集'));
      await tester.pumpAndSettle();
      expect(
        inSection('reference_sources_direct', find.text('Wiki 記事集')),
        findsOneWidget,
      );
      expect(
        inSection(
          'reference_sources_direct',
          find.text(l10n.referenceSources_webCollection),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.common_saveButton));
      await settle(tester);

      expect(find.byType(ReferenceSourcesDialog), findsNothing);
      final stored = (await tester.runAsync(repository.findAll))!;
      expect(
        stored.where((r) => r.child == 'part3').map((r) => r.parent).toSet(),
        {'part2', 'wiki'},
      );
    });

    testWidgets('a failed save keeps the dialog open and says so', (
      tester,
    ) async {
      await pumpDialog(tester, repo: _FailingRepository(novelDatabase));

      await tester.tap(find.text(l10n.common_saveButton));
      await settle(tester);

      expect(find.byType(ReferenceSourcesDialog), findsOneWidget);
      expect(find.text(l10n.referenceSources_saveFailed), findsOneWidget);
    });
  });

  group('while saving', () {
    testWidgets('the dialog cannot be dismissed until the save settles', (
      tester,
    ) async {
      final slow = _SlowRepository(novelDatabase);
      await pumpDialog(tester, repo: slow);

      await tester.tap(find.text(l10n.common_saveButton));
      await tester.pump();
      await tester.tap(find.text(l10n.common_cancelButton));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(ReferenceSourcesDialog), findsOneWidget);

      slow.gate.complete();
      await settle(tester);

      expect(find.byType(ReferenceSourcesDialog), findsNothing);
      expect(find.text(l10n.referenceSources_saveFailed), findsNothing);
    });
  });

  group('load failure', () {
    testWidgets('says the relations could not be read', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            novelReferenceRelationsProvider.overrideWith(
              (ref) async => throw StateError('db broken'),
            ),
            allNovelsProvider.overrideWith((ref) => _novels),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ReferenceSourcesDialog(folderName: 'part3', title: '第3部'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.referenceSources_loadFailed), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('picker', () {
    testWidgets('leaves out the novel, its descendants and current sources', (
      tester,
    ) async {
      await pumpDialog(tester);

      await tester.tap(find.text(l10n.referenceSources_addButton));
      await tester.pumpAndSettle();

      final picker = find.byType(ReferenceSourcePickerDialog);
      Finder inPicker(String text) =>
          find.descendant(of: picker, matching: find.text(text));
      expect(inPicker('第3部'), findsNothing);
      expect(inPicker('外伝'), findsNothing);
      expect(inPicker('第2部'), findsNothing);
      expect(inPicker('第1部'), findsOneWidget);
      expect(inPicker('Wiki 記事集'), findsOneWidget);
      expect(inPicker('別作品'), findsOneWidget);
    });

    testWidgets('narrows candidates by title', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text(l10n.referenceSources_addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reference_source_picker_search')),
        'Wiki',
      );
      await tester.pumpAndSettle();

      final picker = find.byType(ReferenceSourcePickerDialog);
      expect(
        find.descendant(of: picker, matching: find.text('Wiki 記事集')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: picker, matching: find.text('別作品')),
        findsNothing,
      );
    });
  });
}
