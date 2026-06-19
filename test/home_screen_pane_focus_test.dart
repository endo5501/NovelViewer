import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
        ],
        child: const NovelViewerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Walks up the focus tree from the primary focus, looking for a node whose
  // debugLabel marks one of the panes.
  bool paneHasFocus(WidgetTester tester, String label) {
    FocusNode? node = tester.binding.focusManager.primaryFocus;
    while (node != null) {
      if (node.debugLabel == label) return true;
      node = node.parent;
    }
    return false;
  }

  const leftPaneLabel = 'fileBrowserPane';
  const centerPaneLabel = 'novelPane';

  testWidgets('file browser pane has focus on launch',
      (WidgetTester tester) async {
    await pumpApp(tester);
    expect(paneHasFocus(tester, leftPaneLabel), isTrue);
    expect(paneHasFocus(tester, centerPaneLabel), isFalse);
  });

  testWidgets('Tab toggles focus between file browser and novel panes',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(paneHasFocus(tester, leftPaneLabel), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(paneHasFocus(tester, centerPaneLabel), isTrue,
        reason: 'Tab moves focus to the novel pane');
    expect(paneHasFocus(tester, leftPaneLabel), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(paneHasFocus(tester, leftPaneLabel), isTrue,
        reason: 'Tab moves focus back to the file browser pane');
  });

  testWidgets('Tab in the search field does not switch panes',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // Open the search box (Ctrl+F) and let the field take focus.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NovelViewerApp)),
    );
    expect(container.read(searchBoxVisibleProvider), isTrue);

    // Tab while typing must not steal focus to a pane.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(paneHasFocus(tester, leftPaneLabel), isFalse);
    expect(paneHasFocus(tester, centerPaneLabel), isFalse);
  });
}
