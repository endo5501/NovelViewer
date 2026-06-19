import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ScrollableState> pumpRenderer(WidgetTester tester) async {
    // Long content so the horizontal (default) mode is scrollable.
    final content = List.generate(400, (i) => 'これは$i行目の本文です。').join('\n');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<ScrollableState>(find.byType(Scrollable).first);
  }

  testWidgets('arrow down scrolls horizontal mode by about one viewport',
      (WidgetTester tester) async {
    final scrollable = await pumpRenderer(tester);
    expect(scrollable.position.pixels, 0);
    final viewport = scrollable.position.viewportDimension;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(viewport * 0.5),
        reason: 'Arrow down pages forward by roughly one viewport height');
  });

  testWidgets('arrow up scrolls horizontal mode back',
      (WidgetTester tester) async {
    final scrollable = await pumpRenderer(tester);
    final viewport = scrollable.position.viewportDimension;

    // Jump down two viewports first.
    scrollable.position.jumpTo(viewport * 2);
    await tester.pump();
    final start = scrollable.position.pixels;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, lessThan(start),
        reason: 'Arrow up pages backward');
  });
}
