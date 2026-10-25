import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/app/selected_file_progress_title_provider.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/phone_display.dart';

/// The home screen on the portrait display of an iPhone 16 (spec
/// adaptive-shell-layout, "The narrow layout fits a portrait phone").
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const longTitle = '転生したら辺境の村の薬師だったので、のんびり暮らしたいと思います — 049-戦闘.txt (49/200)';
  const episode = FileEntry(
    name: '049-戦闘.txt',
    path: '/library/n1234/049-戦闘.txt',
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    bool withFile = false,
    String title = 'NovelViewer',
  }) async {
    usePhoneDisplay(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          readingProgressStartupProvider.overrideWith(
            (ref) => Completer<void>().future,
          ),
          selectedFileProgressTitleProvider.overrideWithValue(title),
          if (withFile)
            fileContentProvider.overrideWith(
              (ref) async => List.filled(40, '　吾輩は猫である。名前はまだ無い。').join('\n'),
            ),
        ],
        child: const NovelViewerApp(),
      ),
    );
    if (withFile) {
      ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      ).read(selectedFileProvider.notifier).rebase(episode);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('fits with no file open', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('center_column')), findsOneWidget);
  });

  testWidgets('fits with a file open', (tester) async {
    await pumpHome(tester, withFile: true, title: longTitle);

    expect(find.byKey(const Key('center_column')), findsOneWidget);
  });

  testWidgets('keeps every app bar action and a truncated title', (
    tester,
  ) async {
    await pumpHome(tester, withFile: true, title: longTitle);

    for (final key in const [
      'bookmark_button',
      'new_collection_button',
      'search_button',
      'appbar_download_button',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.byIcon(Icons.settings), findsOneWidget);

    final title = find.text(longTitle);
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
    // A share of the bar the reader can see a few characters in, not a sliver.
    expect(tester.getSize(title).width, greaterThanOrEqualTo(64));
  });

  testWidgets('the file browser drawer fits', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('left_column')), findsOneWidget);
  });

  testWidgets('the file browser drawer shows its tab labels whole', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final tabBar = find.descendant(
      of: find.byKey(const Key('left_column')),
      matching: find.byType(TabBar),
    );
    final tabTexts = find.descendant(of: tabBar, matching: find.byType(Text));
    expect(tabTexts, findsWidgets);
    for (final element in tabTexts.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      // A tab label does not wrap; one too long for its tab is faded out at
      // the end, which the paragraph reports as an overflow shader.
      expect(
        paragraph.debugHasOverflowShader || paragraph.didExceedMaxLines,
        isFalse,
        reason: '"${(element.widget as Text).data}" is cut off',
      );
    }
  });

  testWidgets('the search drawer fits', (tester) async {
    await pumpHome(tester, withFile: true);

    await tester.tap(find.byKey(const Key('search_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('right_column')), findsOneWidget);
  });
}
