import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/app.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

void main() {
  testWidgets('NovelViewerApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const NovelViewerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // AppBar title
    expect(find.text('NovelViewer'), findsOneWidget);
    // Settings icon
    expect(find.byIcon(Icons.settings), findsOneWidget);
    // Folder open button should not be present (default directory is used)
    expect(find.byIcon(Icons.folder_open), findsNothing);
  });
}
