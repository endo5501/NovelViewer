import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpRenderer(
    WidgetTester tester, {
    required String content,
    TextDisplayMode mode = TextDisplayMode.horizontal,
    double? height,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: height ?? 400,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (mode == TextDisplayMode.vertical) {
      final element = tester.element(find.byType(TextContentRenderer));
      final container = ProviderScope.containerOf(element);
      await container
          .read(displayModeProvider.notifier)
          .setMode(TextDisplayMode.vertical);
      await tester.pumpAndSettle();
    }
  }

  group('TextContentRenderer', () {
    testWidgets('horizontal mode renders SelectableText.rich',
        (tester) async {
      await pumpRenderer(tester, content: 'テスト小説の内容です。');
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(VerticalTextViewer), findsNothing);
    });

    testWidgets('vertical mode renders VerticalTextViewer', (tester) async {
      await pumpRenderer(
        tester,
        content: 'テスト小説の内容です。',
        mode: TextDisplayMode.vertical,
      );
      expect(find.byType(VerticalTextViewer), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('horizontal mode wraps text in SingleChildScrollView',
        (tester) async {
      await pumpRenderer(tester, content: 'テスト');
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
