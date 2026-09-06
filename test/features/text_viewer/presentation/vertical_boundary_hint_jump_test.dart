import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// A search result or a bookmark reaches the viewer as a target line number,
/// which jumps the page without going through `_changePage`. That path has to
/// drop an armed boundary hint the same way an ordinary page turn does — both
/// because the hint would otherwise sit in the page-number area mid-file, and
/// because a later boundary input would confirm it with no fresh first input.
class _StubSelectedFileNotifier extends SelectedFileNotifier {
  final FileEntry? _initial;
  _StubSelectedFileNotifier(this._initial);

  @override
  FileEntry? build() => _initial;
}

const _ep1 = FileEntry(name: '001-ep1.txt', path: '/novel/001-ep1.txt');
const _ep2 = FileEntry(name: '002-ep2.txt', path: '/novel/002-ep2.txt');
const _ep3 = FileEntry(name: '003-ep3.txt', path: '/novel/003-ep3.txt');

Widget _wrap({required List<TextSegment> segments, int? targetLineNumber}) {
  return ProviderScope(
    overrides: [
      directoryContentsProvider.overrideWith((ref) async {
        return const DirectoryContents(
          files: [_ep1, _ep2, _ep3],
          subdirectories: [],
        );
      }),
      selectedFileProvider.overrideWith(() => _StubSelectedFileNotifier(_ep2)),
    ],
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 100, height: 400),
          child: VerticalTextViewer(
            segments: segments,
            baseStyle: const TextStyle(fontSize: 14.0),
            targetLineNumber: targetLineNumber,
          ),
        ),
      ),
    ),
  );
}

Future<void> _primeAdjacentFiles(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(VerticalTextViewer)),
  );
  await container.read(directoryContentsProvider.future);
  await tester.pumpAndSettle();
  container.read(adjacentFilesProvider);
}

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

Future<void> _navigateToLastPage(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    final indicator = _pageIndicator(tester);
    if (indicator == null) return;
    if (indicator.current >= indicator.total) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
  }
}

void main() {
  // Several pages worth of text, so a target-line jump lands well away from
  // the last page.
  final longSegments = [PlainTextSegment('あ' * 2000)];

  testWidgets('a target-line jump clears an armed boundary hint', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(segments: longSegments));
    await tester.pumpAndSettle();
    await _primeAdjacentFiles(tester);

    await _navigateToLastPage(tester);
    final lastPage = _pageIndicator(tester)!;

    // Arm the next-episode hint: the indicator now shows it instead of "N / M".
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('003-ep3.txt'), findsOneWidget);

    // A search result / bookmark jump to the top of the file.
    await tester.pumpWidget(_wrap(segments: longSegments, targetLineNumber: 0));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('003-ep3.txt'),
      findsNothing,
      reason: 'The hint must not follow the reader to the jump target',
    );
    final afterJump = _pageIndicator(tester);
    expect(afterJump, isNotNull, reason: 'the page number is back');
    expect(afterJump!.current, lessThan(lastPage.total));
  });

  testWidgets('a hint dropped by a jump cannot be confirmed later', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(segments: longSegments));
    await tester.pumpAndSettle();
    await _primeAdjacentFiles(tester);

    await _navigateToLastPage(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('003-ep3.txt'), findsOneWidget);

    // Jump away, then jump straight back to the end inside the 4s window.
    await tester.pumpWidget(_wrap(segments: longSegments, targetLineNumber: 0));
    await tester.pumpAndSettle();
    await _navigateToLastPage(tester);

    // Back at the boundary: this press must arm a fresh hint, not confirm the
    // stale one.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('003-ep3.txt'),
      findsOneWidget,
      reason: 'Still showing the hint means it re-armed instead of confirming',
    );
  });
}
