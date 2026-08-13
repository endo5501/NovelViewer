import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/viewer_selection.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

Widget _buildTestWidget({
  required List<TextSegment> segments,
  double width = 300,
  double height = 400,
  ValueChanged<ViewerSelection?>? onSelectionChanged,
  double columnSpacing = 8.0,
}) {
  return ProviderScope(
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
            onSelectionChanged: onSelectionChanged,
            columnSpacing: columnSpacing,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('VerticalTextViewer pagination', () {
    testWidgets(
      'long line spanning multiple visual columns shows page indicator',
      (tester) async {
        // A single line with 500 characters in a narrow viewport
        // should require multiple pages.
        final longText = 'あ' * 500;
        final segments = [PlainTextSegment(longText)];

        await tester.pumpWidget(
          _buildTestWidget(segments: segments, width: 100, height: 400),
        );

        // Should display page indicator (e.g., "1 / N")
        expect(find.textContaining('/'), findsOneWidget);
      },
    );

    testWidgets('short lines fit in a single page without indicator', (
      tester,
    ) async {
      final segments = [const PlainTextSegment('あいう\nかきく')];

      await tester.pumpWidget(
        _buildTestWidget(segments: segments, width: 600, height: 400),
      );

      // Short content should fit in one page, no indicator
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('multiple long lines are paginated correctly', (tester) async {
      // Multiple lines each spanning several columns in a small viewport
      final segments = [
        PlainTextSegment('${'あ' * 100}\n${'い' * 100}\n${'う' * 100}'),
      ];

      await tester.pumpWidget(
        _buildTestWidget(segments: segments, width: 100, height: 300),
      );

      // Should paginate and show indicator
      expect(find.textContaining('/'), findsOneWidget);
    });
  });

  group('VerticalTextViewer columnSpacing', () {
    testWidgets('larger columnSpacing results in more pages', (tester) async {
      final longText = 'あ' * 500;
      final segments = [PlainTextSegment(longText)];

      // Render with small spacing
      await tester.pumpWidget(
        _buildTestWidget(
          segments: segments,
          width: 200,
          height: 400,
          columnSpacing: 2.0,
        ),
      );
      final smallSpacingIndicator = tester.widget<Text>(
        find.textContaining('/'),
      );
      final smallSpacingPages = smallSpacingIndicator.data!;

      // Render with large spacing
      await tester.pumpWidget(
        _buildTestWidget(
          segments: segments,
          width: 200,
          height: 400,
          columnSpacing: 20.0,
        ),
      );
      final largeSpacingIndicator = tester.widget<Text>(
        find.textContaining('/'),
      );
      final largeSpacingPages = largeSpacingIndicator.data!;

      // More spacing = fewer columns per page = more pages
      final smallTotal = int.parse(smallSpacingPages.split('/').last.trim());
      final largeTotal = int.parse(largeSpacingPages.split('/').last.trim());
      expect(largeTotal, greaterThan(smallTotal));
    });
  });

  group('VerticalTextViewer selection', () {
    testWidgets('onSelectionChanged parameter is accepted', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          segments: const [PlainTextSegment('あいう')],
          onSelectionChanged: (text) {},
        ),
      );

      expect(find.byType(VerticalTextViewer), findsOneWidget);
    });

    testWidgets('page navigation calls onSelectionChanged with null', (
      tester,
    ) async {
      // Create multi-page content
      final longText = 'あ' * 500;
      final segments = [PlainTextSegment(longText)];
      final notifications = <ViewerSelection?>[];

      await tester.pumpWidget(
        _buildTestWidget(
          segments: segments,
          width: 100,
          height: 400,
          onSelectionChanged: notifications.add,
        ),
      );

      // Verify we have multiple pages
      expect(find.textContaining('/'), findsOneWidget);

      // Press left arrow to go to next page
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // onSelectionChanged should have been called with null
      expect(notifications, contains(null));
    });
  });

  group('VerticalTextViewer with empty-base ruby', () {
    // Regression guard: a ruby element whose base text is empty is valid
    // markup on the hosting site. It used to throw StateError inside the
    // column splitter during build, which the release build renders as a
    // blank gray ErrorWidget.
    const segments = <TextSegment>[
      PlainTextSegment('何の'),
      RubyTextSegment(base: '', rubyText: '戦術的優位性'),
      PlainTextSegment('もなかった'),
    ];

    testWidgets('renders the page instead of falling back to ErrorWidget',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        segments: segments,
        width: 600,
        height: 400,
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(VerticalTextViewer), findsOneWidget);
      // Surrounding body text is still laid out.
      expect(find.text('何'), findsOneWidget);
      expect(find.text('た'), findsOneWidget);
    });

    testWidgets('paginates a long line containing an empty-base ruby',
        (tester) async {
      final longSegments = <TextSegment>[
        PlainTextSegment('あ' * 250),
        const RubyTextSegment(base: '', rubyText: 'ルビ'),
        PlainTextSegment('い' * 250),
      ];

      await tester.pumpWidget(_buildTestWidget(
        segments: longSegments,
        width: 100,
        height: 400,
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.textContaining('/'), findsOneWidget);
    });
  });
}
