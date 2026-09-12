import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/tts/presentation/tts_edit_dialog.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_detail_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the wiring a modal surface needs: the edit dialog owns no `Scaffold`,
/// so a failure shown through the page's messenger lands under the modal
/// barrier, where neither the details action nor the close icon can be reached.
///
/// The dialog's `_initialize` builds a real isolate, audio player and
/// databases, so the test never lets it finish — the dialog stays in its
/// loading state, which is enough to exercise the failure presentation.
void main() {
  final packageInfo = PackageInfo(
    appName: 'NovelViewer',
    packageName: 'com.example.novelViewer',
    version: '1.8.2',
    buildNumber: '41',
  );

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // The dialog sits on a CircularProgressIndicator while it loads, so nothing
  // in this tree ever settles; advance by hand instead.
  Future<void> advance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packageInfoProvider.overrideWithValue(packageInfo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/library'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const TtsEditDialog(
                    folderPath: '/library/novel_a',
                    fileName: '040_chapter.txt',
                    content: 'ほんぶん',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
    // Whatever the unmocked isolate/database setup threw on the way is not
    // what this test is about.
    tester.takeException();
  }

  group('TtsEditDialog failure notification', () {
    testWidgets('carries its own messenger around the dialog', (tester) async {
      await pumpDialog(tester);

      expect(
        find.ancestor(
          of: find.byType(AlertDialog),
          matching: find.byType(ScaffoldMessenger),
        ),
        findsWidgets,
        reason: 'the bar has nowhere above the barrier to render without one',
      );
    });

    testWidgets('shows the failure above the barrier, details reachable', (
      tester,
    ) async {
      await pumpDialog(tester);

      // ignore: avoid_dynamic_calls
      (tester.state(find.byType(TtsEditDialog)) as dynamic)
          .showSynthesisFailure('unsupported WAV encoding');
      await advance(tester);
      tester.takeException();

      final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(l10n.failure_detailsAction),
        findsOneWidget,
        reason: 'a bar under the barrier would still be found but not tappable',
      );

      await tester.tap(find.text(l10n.failure_detailsAction));
      await advance(tester);

      expect(find.byType(FailureDetailDialog), findsOneWidget);
    });

    testWidgets('the report names the segment and the file', (tester) async {
      await pumpDialog(tester);

      // ignore: avoid_dynamic_calls
      (tester.state(find.byType(TtsEditDialog)) as dynamic)
          .showSynthesisFailure('unsupported WAV encoding');
      await advance(tester);
      tester.takeException();

      final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
      await tester.tap(find.text(l10n.failure_detailsAction));
      await advance(tester);

      final text = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byType(FailureDetailDialog),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;

      expect(text, contains('app version: 1.8.2+41'));
      expect(text, contains('file: 040_chapter.txt'));
      expect(text, contains('unsupported WAV encoding'));
    });
  });
}
