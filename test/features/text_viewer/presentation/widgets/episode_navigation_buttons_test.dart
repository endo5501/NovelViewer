import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/episode_navigation_buttons.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class _StubSelectedFileNotifier extends SelectedFileNotifier {
  final FileEntry? _initial;
  _StubSelectedFileNotifier(this._initial);

  @override
  FileEntry? build() => _initial;
}

const _ep1 = FileEntry(name: '001-ep1.txt', path: '/novel/001-ep1.txt');
const _ep2 = FileEntry(name: '002-ep2.txt', path: '/novel/002-ep2.txt');
const _ep3 = FileEntry(name: '003-ep3.txt', path: '/novel/003-ep3.txt');

Widget _harness({
  required List<FileEntry> files,
  required FileEntry? selected,
}) {
  return ProviderScope(
    overrides: [
      directoryContentsProvider.overrideWith((ref) async {
        return DirectoryContents(files: files, subdirectories: const []);
      }),
      selectedFileProvider
          .overrideWith(() => _StubSelectedFileNotifier(selected)),
    ],
    child: const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: EpisodeNavigationButtons()),
    ),
  );
}

void main() {
  group('EpisodeNavigationButtons', () {
    testWidgets('middle file: both buttons enabled', (tester) async {
      await tester.pumpWidget(_harness(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
      ));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
          tester.element(find.byType(EpisodeNavigationButtons)));
      await container.read(directoryContentsProvider.future);
      await tester.pumpAndSettle();

      final prevBtn = tester.widget<OutlinedButton>(find.byKey(
          const Key('episode_nav_prev_button')));
      final nextBtn = tester.widget<OutlinedButton>(find.byKey(
          const Key('episode_nav_next_button')));
      expect(prevBtn.onPressed, isNotNull);
      expect(nextBtn.onPressed, isNotNull);
    });

    testWidgets('first file: prev disabled, next enabled', (tester) async {
      await tester.pumpWidget(_harness(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep1,
      ));
      final container = ProviderScope.containerOf(
          tester.element(find.byType(EpisodeNavigationButtons)));
      await container.read(directoryContentsProvider.future);
      await tester.pumpAndSettle();

      final prevBtn = tester.widget<OutlinedButton>(find.byKey(
          const Key('episode_nav_prev_button')));
      final nextBtn = tester.widget<OutlinedButton>(find.byKey(
          const Key('episode_nav_next_button')));
      expect(prevBtn.onPressed, isNull);
      expect(nextBtn.onPressed, isNotNull);
    });

    testWidgets('last file: next disabled, prev enabled', (tester) async {
      await tester.pumpWidget(_harness(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep3,
      ));
      final container = ProviderScope.containerOf(
          tester.element(find.byType(EpisodeNavigationButtons)));
      await container.read(directoryContentsProvider.future);
      await tester.pumpAndSettle();

      final prevBtn = tester.widget<OutlinedButton>(find.byKey(
          const Key('episode_nav_prev_button')));
      final nextBtn = tester.widget<OutlinedButton>(find.byKey(
          const Key('episode_nav_next_button')));
      expect(prevBtn.onPressed, isNotNull);
      expect(nextBtn.onPressed, isNull);
    });

    testWidgets('next button press sets intent=fromStart and switches file',
        (tester) async {
      await tester.pumpWidget(_harness(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
      ));
      final container = ProviderScope.containerOf(
          tester.element(find.byType(EpisodeNavigationButtons)));
      await container.read(directoryContentsProvider.future);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('episode_nav_next_button')));
      await tester.pump();

      expect(container.read(pendingFileEntryIntentProvider),
          FileEntryStartIntent.fromStart);
      expect(container.read(selectedFileProvider), _ep3);
    });

    testWidgets('prev button press sets intent=fromEnd and switches file',
        (tester) async {
      await tester.pumpWidget(_harness(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
      ));
      final container = ProviderScope.containerOf(
          tester.element(find.byType(EpisodeNavigationButtons)));
      await container.read(directoryContentsProvider.future);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('episode_nav_prev_button')));
      await tester.pump();

      expect(container.read(pendingFileEntryIntentProvider),
          FileEntryStartIntent.fromEnd);
      expect(container.read(selectedFileProvider), _ep1);
    });
  });
}
