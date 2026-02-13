import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('TextViewerPanel - font settings', () {
    testWidgets('applies custom font size to horizontal text',
        (tester) async {
      await prefs.setDouble('font_size', 24.0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final selectableText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      final textSpan = selectableText.textSpan!;
      expect(textSpan.style?.fontSize, 24.0);
    });

    testWidgets('applies custom font family to horizontal text',
        (tester) async {
      await prefs.setString('font_family', 'hiraginoMincho');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final selectableText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      final textSpan = selectableText.textSpan!;
      expect(textSpan.style?.fontFamily, 'Hiragino Mincho ProN');
    });

    testWidgets('applies custom font size to vertical text', (tester) async {
      await prefs.setDouble('font_size', 20.0);
      await prefs.setString('text_display_mode', 'vertical');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final viewer = tester.widget<VerticalTextViewer>(
        find.byType(VerticalTextViewer),
      );
      expect(viewer.baseStyle?.fontSize, 20.0);
    });

    testWidgets('applies custom font family to vertical text',
        (tester) async {
      await prefs.setString('font_family', 'yuGothic');
      await prefs.setString('text_display_mode', 'vertical');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final viewer = tester.widget<VerticalTextViewer>(
        find.byType(VerticalTextViewer),
      );
      expect(viewer.baseStyle?.fontFamily, 'YuGothic');
    });

    testWidgets('system font family preserves theme default fontFamily',
        (tester) async {
      // Default is system, so no need to set anything
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fileContentProvider
                .overrideWith((ref) async => 'テスト小説の内容です。'),
          ],
          child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
        ),
      );
      await tester.pumpAndSettle();

      final selectableText =
          tester.widget<SelectableText>(find.byType(SelectableText));
      final textSpan = selectableText.textSpan!;
      // System default preserves the theme's fontFamily (not overriding with a custom one)
      expect(textSpan.style?.fontFamily, isNot('Hiragino Mincho ProN'));
      expect(textSpan.style?.fontFamily, isNot('YuGothic'));
    });
  });
}
