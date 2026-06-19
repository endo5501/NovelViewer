import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_action.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/data/shortcut_bindings.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/presentation/shortcut_settings_section.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpSection(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      shortcutDefaultsProvider
          .overrideWithValue(defaultShortcutBindings(isMacOS: false)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: ShortcutSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> capture(
    WidgetTester tester, {
    required LogicalKeyboardKey modifier,
    required LogicalKeyboardKey key,
  }) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets('lists each action with its current binding',
      (WidgetTester tester) async {
    await pumpSection(tester);

    expect(find.byKey(const Key('shortcut_row_search')), findsOneWidget);
    expect(find.byKey(const Key('shortcut_row_switchPane')), findsOneWidget);
    expect(find.text('Ctrl+F'), findsOneWidget);
    expect(find.text('Tab'), findsOneWidget);
  });

  testWidgets('rebinds an action to an unused key', (WidgetTester tester) async {
    final container = await pumpSection(tester);

    await tester.tap(find.byKey(const Key('shortcut_reassign_bookmark')));
    await tester.pumpAndSettle();
    await capture(tester,
        modifier: LogicalKeyboardKey.controlLeft, key: LogicalKeyboardKey.keyJ);

    expect(
      container.read(keyBindingsProvider)[ShortcutAction.bookmark],
      KeyBinding(keyId: LogicalKeyboardKey.keyJ.keyId, control: true),
    );
  });

  testWidgets('rejects a duplicate key and shows a message',
      (WidgetTester tester) async {
    final container = await pumpSection(tester);
    final originalBookmark =
        container.read(keyBindingsProvider)[ShortcutAction.bookmark];

    // Try to assign Ctrl+F (already used by search) to bookmark.
    await tester.tap(find.byKey(const Key('shortcut_reassign_bookmark')));
    await tester.pumpAndSettle();
    await capture(tester,
        modifier: LogicalKeyboardKey.controlLeft, key: LogicalKeyboardKey.keyF);

    expect(find.text('That key is already assigned to another action'),
        findsOneWidget);
    expect(container.read(keyBindingsProvider)[ShortcutAction.bookmark],
        originalBookmark,
        reason: 'Duplicate is rejected; bookmark keeps its binding');
  });

  testWidgets('rejects a bare printable key without a modifier',
      (WidgetTester tester) async {
    final container = await pumpSection(tester);
    final original =
        container.read(keyBindingsProvider)[ShortcutAction.bookmark];

    await tester.tap(find.byKey(const Key('shortcut_reassign_bookmark')));
    await tester.pumpAndSettle();
    // Press a bare 'J' (no modifier).
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();

    expect(find.text('Shortcuts need a modifier key (Ctrl/Cmd/Alt)'),
        findsOneWidget);
    expect(container.read(keyBindingsProvider)[ShortcutAction.bookmark],
        original,
        reason: 'A bare printable key is rejected; binding unchanged');
  });

  testWidgets('Escape cancels the capture without rebinding',
      (WidgetTester tester) async {
    final container = await pumpSection(tester);
    final original =
        container.read(keyBindingsProvider)[ShortcutAction.bookmark];

    await tester.tap(find.byKey(const Key('shortcut_reassign_bookmark')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(container.read(keyBindingsProvider)[ShortcutAction.bookmark],
        original,
        reason: 'Escape cancels capture; Escape is not bound');
  });

  testWidgets('reset to defaults restores bindings',
      (WidgetTester tester) async {
    final container = await pumpSection(tester);

    await container.read(keyBindingsProvider.notifier).rebind(
          ShortcutAction.bookmark,
          KeyBinding(keyId: LogicalKeyboardKey.keyJ.keyId, control: true),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shortcut_reset_defaults')));
    await tester.pumpAndSettle();

    expect(container.read(keyBindingsProvider),
        defaultShortcutBindings(isMacOS: false));
  });
}
