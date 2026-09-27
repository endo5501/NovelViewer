import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole route, from a finger on the vertical text to the drawer the
/// shell owns: the page, the viewer, the renderer and the shell each carry
/// one step of it.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Mounts the app in the narrow layout, as on an iPad in portrait, with a
  /// short text open in vertical mode. Restoration is left pending so the
  /// drawer does not open on its own at startup.
  Future<void> pumpVerticalApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          shellBreakpointProvider.overrideWithValue(900),
          readingProgressStartupProvider.overrideWith(
            (ref) => Completer<void>().future,
          ),
          fileContentProvider.overrideWith((ref) async => '昨日アリスが来た。'),
        ],
        child: const NovelViewerApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NovelViewerApp)),
    );
    await container
        .read(displayModeProvider.notifier)
        .setMode(TextDisplayMode.vertical);
    await tester.pumpAndSettle();
  }

  Offset emptyMiddleOfPage(WidgetTester tester) {
    final page = tester.getRect(find.byType(VerticalTextPage));
    return Offset(page.center.dx, page.bottom - 40);
  }

  testWidgets('a finger double tap in the middle opens the drawer', (
    tester,
  ) async {
    await pumpVerticalApp(tester);
    expect(find.byKey(const Key('left_column')), findsNothing);

    final target = emptyMiddleOfPage(tester);
    await tester.tapAt(target);
    await tester.pump();
    await tester.tapAt(target);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('left_column')), findsOneWidget);
  });

  testWidgets('a single tap in the middle leaves the drawer closed', (
    tester,
  ) async {
    await pumpVerticalApp(tester);

    await tester.tapAt(emptyMiddleOfPage(tester));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('left_column')), findsNothing);
  });
}
