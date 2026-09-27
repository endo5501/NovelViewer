import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The renderer is where the viewer's center double tap becomes a request for
/// the file browser drawer, which the shell answers. Only the vertical viewer
/// makes the request: in horizontal mode a double tap selects a word.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const content = '昨日アリスが来た。';
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpRenderer(
    WidgetTester tester,
    TextDisplayMode mode,
  ) async {
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
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextContentRenderer)),
    );
    await container.read(displayModeProvider.notifier).setMode(mode);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> doubleTapAt(WidgetTester tester, Offset position) async {
    await tester.tapAt(position);
    await tester.pump();
    await tester.tapAt(position);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('a center double tap in vertical mode asks for the drawer', (
    tester,
  ) async {
    final container = await pumpRenderer(tester, TextDisplayMode.vertical);
    final before = container.read(fileBrowserOpenRequestProvider);

    final page = tester.getRect(find.byType(VerticalTextPage));
    await doubleTapAt(tester, Offset(page.center.dx, page.bottom - 40));

    expect(container.read(fileBrowserOpenRequestProvider), before + 1);
  });

  testWidgets('a double tap in horizontal mode asks for nothing', (
    tester,
  ) async {
    // A regression guard: horizontal mode has no route to the request, and
    // must not gain one, because there a double tap selects a word.
    final container = await pumpRenderer(tester, TextDisplayMode.horizontal);
    final before = container.read(fileBrowserOpenRequestProvider);

    await doubleTapAt(
      tester,
      tester.getCenter(find.byType(TextContentRenderer)),
    );

    expect(container.read(fileBrowserOpenRequestProvider), before);
  });
}
