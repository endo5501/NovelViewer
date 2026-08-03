import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/data/viewer_selection.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Vertical mode must report the selection start as a document-global
/// plain-text offset: the page-local walk over char entries (ruby counts as
/// its base length, a real line break as 1, a visual column wrap as 0) plus
/// the page's own `pageStartTextOffset`.
///
/// The assertions here check the invariant that ties the two reported values
/// together — the offset must point at exactly where the reported text starts
/// in the page's plain text — rather than hard-coding an entry index. Where a
/// drag begins depends on the touch slop, which is not what these tests are
/// about; the arithmetic itself is pinned by the unit tests for
/// `plainTextOffsetFromEntryIndex`.
Widget _buildTestWidget({
  required List<TextSegment> segments,
  required ValueChanged<ViewerSelection?> onSelectionChanged,
  int pageStartTextOffset = 0,
  Set<int>? lineBreakEntryIndices,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 300,
        child: VerticalTextPage(
          segments: segments,
          baseStyle: const TextStyle(fontSize: 14.0),
          pageStartTextOffset: pageStartTextOffset,
          lineBreakEntryIndices: lineBreakEntryIndices,
          onSelectionChanged: onSelectionChanged,
        ),
      ),
    ),
  );
}

/// Drags down a column from [from] to [to] so the page enters selecting mode.
Future<void> _dragSelect(WidgetTester tester, String from, String to) async {
  final start = tester.getCenter(find.text(from));
  final end = tester.getCenter(find.text(to));
  await tester.timedDragFrom(
    start,
    end - start,
    const Duration(milliseconds: 300),
  );
  await tester.pumpAndSettle();
}

/// Asserts the reported offset addresses the reported text inside
/// [pagePlainText], after removing the page origin.
void expectOffsetAddressesText(
  ViewerSelection? selection, {
  required String pagePlainText,
  required int pageStartTextOffset,
}) {
  expect(selection, isNotNull, reason: 'a drag must report a selection');
  final local = selection!.plainTextOffset - pageStartTextOffset;
  expect(local, inInclusiveRange(0, pagePlainText.length));
  expect(
    pagePlainText.startsWith(selection.text, local),
    isTrue,
    reason: 'offset $local should address "${selection.text}" in '
        '"$pagePlainText", but that position holds '
        '"${pagePlainText.substring(local)}"',
  );
}

void main() {
  testWidgets('offset addresses the selected text in plain-text coordinates',
      (tester) async {
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      segments: const [PlainTextSegment('あいうえお')],
      onSelectionChanged: notifications.add,
    ));

    await _dragSelect(tester, 'い', 'え');

    expectOffsetAddressesText(
      notifications.last,
      pagePlainText: 'あいうえお',
      pageStartTextOffset: 0,
    );
  });

  testWidgets('adds pageStartTextOffset to make the offset document-global',
      (tester) async {
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      segments: const [PlainTextSegment('あいうえお')],
      pageStartTextOffset: 800,
      onSelectionChanged: notifications.add,
    ));

    await _dragSelect(tester, 'い', 'え');

    expect(notifications.last!.plainTextOffset, greaterThanOrEqualTo(800),
        reason: 'the page origin must be added, not dropped');
    expectOffsetAddressesText(
      notifications.last,
      pagePlainText: 'あいうえお',
      pageStartTextOffset: 800,
    );
  });

  testWidgets('ruby before the selection advances by its base length',
      (tester) async {
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      // Entries: あ(0) [ruby=漢字](1) い(2) う(3) え(4)
      segments: const [
        PlainTextSegment('あ'),
        RubyTextSegment(base: '漢字', rubyText: 'かんじ'),
        PlainTextSegment('いうえ'),
      ],
      onSelectionChanged: notifications.add,
    ));

    await _dragSelect(tester, 'い', 'え');

    // Counting the ruby entry as one character would land the offset two
    // positions early, inside "漢字".
    expectOffsetAddressesText(
      notifications.last,
      pagePlainText: 'あ漢字いうえ',
      pageStartTextOffset: 0,
    );
  });

  testWidgets('real line break before the selection counts as one character',
      (tester) async {
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      // Entries: あ(0) い(1) \n(2) う(3) え(4) お(5)
      segments: const [
        PlainTextSegment('あい'),
        PlainTextSegment('\n'),
        PlainTextSegment('うえお'),
      ],
      lineBreakEntryIndices: const {2},
      onSelectionChanged: notifications.add,
    ));

    await _dragSelect(tester, 'う', 'お');

    expectOffsetAddressesText(
      notifications.last,
      pagePlainText: 'あい\nうえお',
      pageStartTextOffset: 0,
    );
  });

  testWidgets('visual column wrap before the selection counts as zero',
      (tester) async {
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      // Same entries, but the newline is a pagination wrap, not a paragraph
      // break, so it contributes no character to the original text.
      segments: const [
        PlainTextSegment('あい'),
        PlainTextSegment('\n'),
        PlainTextSegment('うえお'),
      ],
      lineBreakEntryIndices: const {},
      onSelectionChanged: notifications.add,
    ));

    await _dragSelect(tester, 'う', 'お');

    expectOffsetAddressesText(
      notifications.last,
      pagePlainText: 'あいうえお',
      pageStartTextOffset: 0,
    );
  });

  testWidgets('without pagination metadata the text and offset still agree',
      (tester) async {
    // No lineBreakEntryIndices: extractVerticalSelectedText's legacy reading
    // treats every newline as a real paragraph break, so the offset walk must
    // count them too. Falling back to an empty set would report text holding
    // a newline next to an offset that skipped it.
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      segments: const [
        PlainTextSegment('あい'),
        PlainTextSegment('\n'),
        PlainTextSegment('うえお'),
      ],
      onSelectionChanged: notifications.add,
    ));

    await _dragSelect(tester, 'う', 'お');

    expectOffsetAddressesText(
      notifications.last,
      pagePlainText: 'あい\nうえお',
      pageStartTextOffset: 0,
    );
  });

  testWidgets('carries the selected text alongside the offset', (tester) async {
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      segments: const [PlainTextSegment('あいうえお')],
      onSelectionChanged: notifications.add,
    ));

    await _dragSelect(tester, 'い', 'え');

    expect(notifications.last?.text, isNotNull);
    expect(notifications.last!.text, isNotEmpty);
  });

  testWidgets('tap clears the selection with null', (tester) async {
    final notifications = <ViewerSelection?>[];
    await tester.pumpWidget(_buildTestWidget(
      segments: const [PlainTextSegment('あいうえお')],
      onSelectionChanged: notifications.add,
    ));

    await tester.tap(find.text('い'));
    await tester.pumpAndSettle();

    expect(notifications.last, isNull);
  });
}
