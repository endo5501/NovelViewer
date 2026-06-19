import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'search shortcut respects a customized binding (Ctrl+G) from settings',
      (WidgetTester tester) async {
    // Persist a custom binding: search = Ctrl+G instead of the default Ctrl+F.
    final custom = Map<ShortcutAction, KeyBinding>.from(
      defaultShortcutBindings(isMacOS: false),
    );
    custom[ShortcutAction.search] =
        KeyBinding(keyId: LogicalKeyboardKey.keyG.keyId, control: true);
    SharedPreferences.setMockInitialValues({
      'keyboard_shortcuts': ShortcutBindingCodec.encode(custom),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
          shortcutDefaultsProvider
              .overrideWithValue(defaultShortcutBindings(isMacOS: false)),
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
    expect(container.read(searchBoxVisibleProvider), isFalse,
        reason: 'Ctrl+F should no longer trigger search after rebinding');

    // The customized Ctrl+G triggers search.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(container.read(searchBoxVisibleProvider), isTrue,
        reason: 'Customized Ctrl+G should trigger search');
  });
}
