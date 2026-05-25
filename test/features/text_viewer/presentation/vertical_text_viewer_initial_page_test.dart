import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

Widget _wrap({
  required ProviderContainer container,
  required List<TextSegment> segments,
  double width = 100,
  double height = 400,
}) {
  return UncontrolledProviderScope(
    container: container,
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

/// Returns (current, total) parsed from the page indicator. Returns null when
/// the indicator is absent (single page).
({int current, int total})? _readIndicator(WidgetTester tester) {
  final finder = find.textContaining('/');
  if (finder.evaluate().isEmpty) return null;
  final text = tester.widget<Text>(finder).data!;
  final parts = text.split('/');
  return (
    current: int.parse(parts[0].trim()),
    total: int.parse(parts[1].trim())
  );
}

void main() {
  final longSegments = [PlainTextSegment('あ' * 500)];

  group('VerticalTextViewer initial-page intent consumption', () {
    testWidgets('intent=fromStart opens on page 1', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromStart);

      await tester.pumpWidget(_wrap(
        container: container,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();

      final indicator = _readIndicator(tester);
      expect(indicator, isNotNull);
      expect(indicator!.current, 1);
      // Intent must be cleared after the viewer consumes it once.
      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    testWidgets('intent=fromEnd opens on the last page', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);

      await tester.pumpWidget(_wrap(
        container: container,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();

      final indicator = _readIndicator(tester);
      expect(indicator, isNotNull);
      expect(indicator!.current, indicator.total,
          reason: 'fromEnd intent should land the viewer on the last page');
      // Intent must be cleared after the viewer consumes it once.
      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    testWidgets('null intent opens on page 1 (the default)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // No intent set.

      await tester.pumpWidget(_wrap(
        container: container,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();

      final indicator = _readIndicator(tester);
      expect(indicator, isNotNull);
      expect(indicator!.current, 1);
      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    testWidgets('intent=fromEnd is consumed exactly once across rebuilds',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);

      await tester.pumpWidget(_wrap(
        container: container,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();

      // Already cleared.
      expect(container.read(pendingFileEntryIntentProvider), isNull);

      // Set the intent again to fromStart manually — a fresh build with the
      // *same segments* should NOT re-consume it (consumption only happens
      // on initState and on segments-change).
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromStart);
      await tester.pumpWidget(_wrap(
        container: container,
        segments: longSegments,
      ));
      await tester.pumpAndSettle();

      expect(
        container.read(pendingFileEntryIntentProvider),
        FileEntryStartIntent.fromStart,
        reason: 'Same-segment rebuild must not consume a fresh intent',
      );
    });
  });
}
