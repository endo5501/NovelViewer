import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
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

Widget _wrap({
  required List<FileEntry> files,
  required FileEntry? selected,
  required List<TextSegment> segments,
  double width = 100,
  double height = 400,
}) {
  return ProviderScope(
    overrides: [
      directoryContentsProvider.overrideWith((ref) async {
        return DirectoryContents(files: files, subdirectories: const []);
      }),
      selectedFileProvider
          .overrideWith(() => _StubSelectedFileNotifier(selected)),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: width, height: height),
          child: VerticalTextViewer(
            segments: segments,
            baseStyle: const TextStyle(fontSize: 14.0),
          ),
        ),
      ),
    ),
  );
}

/// Force-loads the directory listing so that `adjacentFilesProvider` resolves
/// to its real value before the first synchronous `ref.read` from
/// `_handleBoundaryNavigation`. Without this, the provider would observe
/// `directoryContentsProvider` in its initial loading state and report
/// `AdjacentFiles.empty`.
/// Force-loads the directory listing AND materialises `adjacentFilesProvider`
/// before the test sends any input. Without this, the viewer's first
/// synchronous `ref.read(adjacentFilesProvider)` from `_handleBoundaryNavigation`
/// can capture the listing while it is still in its `AsyncLoading` state and
/// see `AdjacentFiles.empty`.
Future<void> _primeAdjacentFiles(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
      tester.element(find.byType(VerticalTextViewer)));
  await container.read(directoryContentsProvider.future);
  await tester.pumpAndSettle();
  container.read(adjacentFilesProvider);
}

Future<void> _navigateToLastPage(WidgetTester tester) async {
  // Press left-arrow until the page indicator reaches N / N. Stopping at the
  // boundary is critical because *another* press would trip the 2-step
  // boundary handler (potentially firing the very navigation the test is
  // trying to set up).
  for (var i = 0; i < 50; i++) {
    final indicator = _pageIndicator(tester);
    if (indicator == null) return;
    if (indicator.current >= indicator.total) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
  }
}

/// Returns the (current, total) page numbers from the "N / M" indicator,
/// or null if no indicator is currently shown.
({int current, int total})? _pageIndicator(WidgetTester tester) {
  final finder = find.textContaining('/');
  if (finder.evaluate().isEmpty) return null;
  final text = tester.widget<Text>(finder).data!;
  final parts = text.split('/');
  if (parts.length != 2) return null;
  final current = int.tryParse(parts[0].trim());
  final total = int.tryParse(parts[1].trim());
  if (current == null || total == null) return null;
  return (current: current, total: total);
}

void main() {
  final longSegments = [PlainTextSegment('あ' * 500)];

  group('VerticalTextViewer 2-step next-episode navigation', () {
    testWidgets('arrow on last page shows next-episode prompt', (tester) async {
      await tester.pumpWidget(_wrap(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();
      await _primeAdjacentFiles(tester);

      await _navigateToLastPage(tester);
      // Sanity: indicator currently shows last page.
      final indicator = _pageIndicator(tester);
      expect(indicator, isNotNull);
      expect(indicator!.current, indicator.total);

      // Press once: triggers prompt, not navigation.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(find.textContaining('003-ep3.txt'), findsOneWidget,
          reason: 'Prompt should mention the next episode name');
      expect(find.textContaining('もう一度'), findsOneWidget,
          reason: 'Prompt should hint to press again');
    });

    testWidgets('second press confirms and sets intent=fromStart',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(_wrap(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
          tester.element(find.byType(VerticalTextViewer)));
      await _primeAdjacentFiles(tester);

      await _navigateToLastPage(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(container.read(pendingFileEntryIntentProvider),
          FileEntryStartIntent.fromStart);
      expect(container.read(selectedFileProvider), _ep3);
    });

    testWidgets('prompt disappears after timeout', (tester) async {
      await tester.pumpWidget(_wrap(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();
      await _primeAdjacentFiles(tester);
      await _navigateToLastPage(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.textContaining('もう一度'), findsOneWidget);

      // Wait beyond the prompt timeout (4s) and verify it's cleared.
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('もう一度'), findsNothing);
      final indicator = _pageIndicator(tester);
      expect(indicator, isNotNull,
          reason: 'Page number indicator should return after timeout');
    });

    testWidgets('on the very last episode the prompt does not appear',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(_wrap(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep3,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
          tester.element(find.byType(VerticalTextViewer)));

      await _navigateToLastPage(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(find.textContaining('もう一度'), findsNothing,
          reason: 'No next episode → no prompt');
      expect(container.read(pendingFileEntryIntentProvider), isNull);
      expect(container.read(selectedFileProvider), _ep3);
    });
  });

  group('VerticalTextViewer 2-step previous-episode navigation', () {
    testWidgets('arrow on first page shows previous-episode prompt',
        (tester) async {
      await tester.pumpWidget(_wrap(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();
      await _primeAdjacentFiles(tester);

      // We start on page 1 of episode 2. Right arrow attempts to go back.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(find.textContaining('001-ep1.txt'), findsOneWidget);
      expect(find.textContaining('もう一度'), findsOneWidget);
    });

    testWidgets('second press confirms and sets intent=fromEnd',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(_wrap(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep2,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
          tester.element(find.byType(VerticalTextViewer)));
      await _primeAdjacentFiles(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(container.read(pendingFileEntryIntentProvider),
          FileEntryStartIntent.fromEnd);
      expect(container.read(selectedFileProvider), _ep1);
    });

    testWidgets('on the very first episode the prompt does not appear',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(_wrap(
        files: const [_ep1, _ep2, _ep3],
        selected: _ep1,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
          tester.element(find.byType(VerticalTextViewer)));
      await _primeAdjacentFiles(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(find.textContaining('もう一度'), findsNothing);
      expect(container.read(pendingFileEntryIntentProvider), isNull);
      expect(container.read(selectedFileProvider), _ep1);
    });
  });
}
