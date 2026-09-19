import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/shared/providers/layout_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'search shortcut respects a customized binding (Ctrl+G) from settings',
    (WidgetTester tester) async {
      // Persist a custom binding: search = Ctrl+G instead of the default Ctrl+F.
      final custom = Map<ShortcutAction, KeyBinding>.from(
        defaultShortcutBindings(isApplePlatform: false),
      );
      custom[ShortcutAction.search] = KeyBinding(
        keyId: LogicalKeyboardKey.keyG.keyId,
        control: true,
      );
      SharedPreferences.setMockInitialValues({
        'keyboard_shortcuts': ShortcutBindingCodec.encode(custom),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            shortcutDefaultsProvider.overrideWithValue(
              defaultShortcutBindings(isApplePlatform: false),
            ),
            readingProgressStartupProvider.overrideWith(
              (ref) => Completer<void>().future,
            ),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(NovelViewerApp)),
      );

      expect(container.read(searchBoxVisibleProvider), isFalse);

      // The default Ctrl+F must NOT trigger search (it was rebound away).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(
        container.read(searchBoxVisibleProvider),
        isFalse,
        reason: 'Ctrl+F should no longer trigger search after rebinding',
      );

      // The customized Ctrl+G triggers search.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
      expect(
        container.read(searchBoxVisibleProvider),
        isTrue,
        reason: 'Customized Ctrl+G should trigger search',
      );
    },
  );

  group('the file browser toggle is registered in both layouts', () {
    /// Mounts the app at the given breakpoint with nothing else customized.
    /// The test surface is 800x600, so a breakpoint above it gives the narrow
    /// layout without resizing.
    Future<void> pumpApp(
      WidgetTester tester, {
      required double breakpoint,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            shellBreakpointProvider.overrideWithValue(breakpoint),
            shortcutDefaultsProvider.overrideWithValue(
              defaultShortcutBindings(isApplePlatform: false),
            ),
            readingProgressStartupProvider.overrideWith(
              (ref) => Completer<void>().future,
            ),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Tab reaches the drawer in the wide layout', (tester) async {
      await pumpApp(tester, breakpoint: 800);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('left_column')), findsOneWidget);
    });

    testWidgets('Tab reaches the drawer in the narrow layout', (tester) async {
      // The old pane switch was withheld here; the drawer it now toggles is
      // present at every width, so the binding is too.
      await pumpApp(tester, breakpoint: 900);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('left_column')), findsOneWidget);
    });

    testWidgets('a rebound toggle replaces Tab', (tester) async {
      final custom = Map<ShortcutAction, KeyBinding>.from(
        defaultShortcutBindings(isApplePlatform: false),
      );
      custom[ShortcutAction.toggleFileBrowser] = KeyBinding(
        keyId: LogicalKeyboardKey.keyE.keyId,
        control: true,
      );
      SharedPreferences.setMockInitialValues({
        'keyboard_shortcuts': ShortcutBindingCodec.encode(custom),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue('/library'),
            shortcutDefaultsProvider.overrideWithValue(
              defaultShortcutBindings(isApplePlatform: false),
            ),
            readingProgressStartupProvider.overrideWith(
              (ref) => Completer<void>().future,
            ),
          ],
          child: const NovelViewerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('left_column')),
        findsNothing,
        reason: 'Tab was rebound away',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('left_column')), findsOneWidget);
    });
  });
}
