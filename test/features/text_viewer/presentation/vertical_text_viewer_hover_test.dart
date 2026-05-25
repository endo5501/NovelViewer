import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

Widget _build({
  required List<TextSegment> segments,
  Map<String, MarkStyle> markedWords = const {},
  void Function(String word, Offset position, HoverToken token)? onMarkEnter,
  void Function(HoverToken token)? onMarkExit,
  VoidCallback? onHoverHideRequest,
  ValueChanged<String?>? onSelectionChanged,
  double width = 200,
  double height = 400,
}) {
  return ProviderScope(child: MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: width, height: height),
        child: VerticalTextViewer(
          segments: segments,
          baseStyle: const TextStyle(fontSize: 14.0),
          markedWords: markedWords,
          onMarkEnter: onMarkEnter,
          onMarkExit: onMarkExit,
          onHoverHideRequest: onHoverHideRequest,
          onSelectionChanged: onSelectionChanged,
        ),
      ),
    ),
  ));
}

void main() {
  group('VerticalTextViewer hover callbacks — passthrough to VerticalTextPage',
      () {
    testWidgets('forwards onMarkEnter / onMarkExit / onHoverHideRequest props',
        (tester) async {
      void enter(String _, Offset _, HoverToken _) {}
      void exit(HoverToken _) {}
      void hide() {}

      await tester.pumpWidget(_build(
        segments: const [PlainTextSegment('アリスが歩く')],
        markedWords: const {'アリス': MarkStyle.solid},
        onMarkEnter: enter,
        onMarkExit: exit,
        onHoverHideRequest: hide,
      ));
      await tester.pumpAndSettle();

      final page = tester.widget<VerticalTextPage>(find.byType(VerticalTextPage));
      expect(page.onMarkEnter, same(enter));
      expect(page.onMarkExit, same(exit));
      expect(page.onHoverHideRequest, same(hide));
    });

    testWidgets('passes null callbacks through unchanged', (tester) async {
      await tester.pumpWidget(_build(
        segments: const [PlainTextSegment('アリスが歩く')],
      ));
      await tester.pumpAndSettle();

      final page = tester.widget<VerticalTextPage>(find.byType(VerticalTextPage));
      expect(page.onMarkEnter, isNull);
      expect(page.onMarkExit, isNull);
      expect(page.onHoverHideRequest, isNull);
    });
  });

  group('VerticalTextViewer._changePage — fires hide alongside selection clear',
      () {
    testWidgets(
      'pressing arrow key to advance a page calls onHoverHideRequest, '
      'and onSelectionChanged(null) fires too',
      (tester) async {
        final events = <String>[];
        // Multi-page content so arrow keys actually trigger _changePage.
        await tester.pumpWidget(_build(
          segments: [PlainTextSegment('あ' * 500)],
          onSelectionChanged: (text) =>
              events.add('selection:${text ?? "null"}'),
          onHoverHideRequest: () => events.add('hide'),
        ));
        await tester.pumpAndSettle();

        // Tap to give focus to the viewer.
        await tester.tap(find.byType(VerticalTextViewer));
        await tester.pump();
        // The tap fires onSelectionChanged(null) as part of clearing the
        // empty selection; drop those bookkeeping events so the assertion
        // focuses on what _changePage emits.
        events.clear();

        // Trigger _changePage via arrow key — left arrow = next page.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        // Must fire onSelectionChanged(null) AND onHoverHideRequest from
        // _changePage. The implementation invokes them in that order.
        expect(events, containsAll(['selection:null', 'hide']));
        final selectionIdx = events.indexOf('selection:null');
        final hideIdx = events.indexOf('hide');
        expect(hideIdx, greaterThan(selectionIdx),
            reason: 'onHoverHideRequest must follow onSelectionChanged(null)');
      },
    );

    testWidgets(
      'when there is no next page, _changePage is a no-op and does NOT fire '
      'onHoverHideRequest',
      (tester) async {
        var hideCount = 0;
        // Single-page content: only one column fits, so arrow key can't advance.
        await tester.pumpWidget(_build(
          segments: const [PlainTextSegment('あ')],
          onHoverHideRequest: () => hideCount++,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(VerticalTextViewer));
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(hideCount, 0);
      },
    );
  });

  group('VerticalTextViewer — target line jump (bookmark/search) hides popup',
      () {
    testWidgets(
      'changing targetLineNumber to a line on a different page fires '
      'onHoverHideRequest so a visible popup does not linger over the new page',
      (tester) async {
        var hideCount = 0;
        void Function()? onHide() => () => hideCount++;
        Widget buildWith({int? target}) => ProviderScope(child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints.tightFor(width: 200, height: 400),
                  child: VerticalTextViewer(
                    // Multi-line content where line N is on a later page than line 1.
                    segments: [
                      PlainTextSegment(
                          List.generate(30, (i) => 'ぎょう$i').join('\n')),
                    ],
                    baseStyle: const TextStyle(fontSize: 14.0),
                    targetLineNumber: target,
                    onHoverHideRequest: onHide(),
                  ),
                ),
              ),
            ));

        await tester.pumpWidget(buildWith());
        await tester.pumpAndSettle();
        hideCount = 0;

        // Jump to a later line — should land on a different page via the
        // post-frame setState path (not via _changePage).
        await tester.pumpWidget(buildWith(target: 25));
        await tester.pumpAndSettle();

        expect(hideCount, 1,
            reason:
                'Auto-jump must hide exactly once even though build() may '
                'run multiple times in the same frame — duplicate '
                'addPostFrameCallback registrations should be deduped');
      },
    );
  });
}
