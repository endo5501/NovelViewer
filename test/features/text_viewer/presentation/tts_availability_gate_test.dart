import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/tts_controls_bar.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The TTS controls bar is the only on-screen route to the TTS native engine,
/// and that engine is a `.dylib` that does not exist on iOS. Rendering the bar
/// in a disabled state would still leave the file-delete and export entry
/// points in the tree, so the bar is omitted entirely where TTS is
/// unavailable.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget build({required bool ttsSupported}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
        fileContentProvider.overrideWith((ref) async => 'テスト小説の内容です。'),
        ttsSupportedProvider.overrideWithValue(ttsSupported),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TextViewerPanel()),
      ),
    );
  }

  testWidgets('the controls bar is present where TTS is supported', (
    tester,
  ) async {
    await tester.pumpWidget(build(ttsSupported: true));
    await tester.pumpAndSettle();

    expect(find.byType(TtsControlsBar), findsOneWidget);
  });

  testWidgets('the controls bar is absent where TTS is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(build(ttsSupported: false));
    await tester.pumpAndSettle();

    expect(find.byType(TtsControlsBar), findsNothing);
  });

  testWidgets('the text still renders without the controls bar', (
    tester,
  ) async {
    // Removing the bar must not disturb the viewer it was overlaid on.
    await tester.pumpWidget(build(ttsSupported: false));
    await tester.pumpAndSettle();

    expect(find.text('テスト小説の内容です。'), findsOneWidget);
  });
}
