import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

Widget _wrap({
  required ProviderContainer container,
  required List<TextSegment> segments,
  double width = 120,
  double height = 400,
  TextStyle baseStyle = const TextStyle(fontSize: 14.0),
  String? query,
  int? targetLineNumber,
  int? ttsHighlightStart,
  int? ttsHighlightEnd,
  List<int> bookmarkLineNumbers = const [],
  double columnSpacing = 8.0,
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
            baseStyle: baseStyle,
            query: query,
            targetLineNumber: targetLineNumber,
            ttsHighlightStart: ttsHighlightStart,
            ttsHighlightEnd: ttsHighlightEnd,
            bookmarkLineNumbers: bookmarkLineNumbers,
            columnSpacing: columnSpacing,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => verticalPaginationHeavyCount = 0);

  // A multi-line, multi-page document so pagination does real work.
  final segments = <TextSegment>[
    PlainTextSegment(List.generate(40, (i) => 'あいうえお' * 4).join('\n')),
  ];

  group('F115: pagination memoization', () {
    testWidgets('unchanged inputs reuse cached pagination (TTS tick)', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container: container, segments: segments));
      await tester.pump();
      verticalPaginationHeavyCount = 0;

      // A TTS highlight change forces the viewer to rebuild but does not change
      // segments / constraints / style / columnSpacing.
      await tester.pumpWidget(_wrap(
        container: container,
        segments: segments,
        ttsHighlightStart: 3,
        ttsHighlightEnd: 6,
      ));
      await tester.pump();

      expect(verticalPaginationHeavyCount, 0,
          reason: 'heavy pagination must not recompute on a TTS tick');
    });

    testWidgets('unchanged inputs reuse cached pagination (query change)', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container: container, segments: segments));
      await tester.pump();
      verticalPaginationHeavyCount = 0;

      await tester.pumpWidget(
          _wrap(container: container, segments: segments, query: 'あ'));
      await tester.pump();

      expect(verticalPaginationHeavyCount, 0);
    });

    testWidgets('changed constraints recompute pagination', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
          _wrap(container: container, segments: segments, width: 120));
      await tester.pump();
      verticalPaginationHeavyCount = 0;

      await tester.pumpWidget(
          _wrap(container: container, segments: segments, width: 220));
      await tester.pump();

      expect(verticalPaginationHeavyCount, greaterThan(0),
          reason: 'a width change must re-paginate');
    });

    testWidgets('changed font style recomputes pagination', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container: container,
        segments: segments,
        baseStyle: const TextStyle(fontSize: 14.0),
      ));
      await tester.pump();
      verticalPaginationHeavyCount = 0;

      await tester.pumpWidget(_wrap(
        container: container,
        segments: segments,
        baseStyle: const TextStyle(fontSize: 22.0),
      ));
      await tester.pump();

      expect(verticalPaginationHeavyCount, greaterThan(0),
          reason: 'a font-size change must re-paginate');
    });

    testWidgets('bookmark-only change does not invalidate cached layout', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container: container,
        segments: segments,
        bookmarkLineNumbers: const [],
      ));
      await tester.pump();
      verticalPaginationHeavyCount = 0;

      await tester.pumpWidget(_wrap(
        container: container,
        segments: segments,
        bookmarkLineNumbers: const [3],
      ));
      await tester.pump();

      expect(verticalPaginationHeavyCount, 0,
          reason: 'bookmark changes only touch the light layer');
    });

    testWidgets('target-line-only change does not invalidate cached layout but '
        'navigates to the target page', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container: container,
        segments: segments,
        targetLineNumber: 1,
      ));
      await tester.pumpAndSettle();
      verticalPaginationHeavyCount = 0;

      // Jump to a late line: the light-layer targetPage must update (page
      // indicator advances) while the heavy layer stays cached.
      await tester.pumpWidget(_wrap(
        container: container,
        segments: segments,
        targetLineNumber: 40,
      ));
      await tester.pumpAndSettle();

      expect(verticalPaginationHeavyCount, 0,
          reason: 'a target-line jump only touches the light layer');

      final indicator = find.textContaining('/');
      expect(indicator, findsOneWidget);
      final text = tester.widget<Text>(indicator).data!;
      final current = int.parse(text.split('/')[0].trim());
      expect(current, greaterThan(1),
          reason: 'targetPage should have advanced past page 1');
    });
  });
}
