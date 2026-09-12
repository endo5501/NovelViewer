import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_detail_dialog.dart';
import 'package:novel_viewer/shared/failure/failure_report.dart';

void main() {
  final report = FailureReport(
    headline: '解析に失敗しました',
    cause: 'LlmAnalysisPartialFailure: 3 file(s) failed extraction',
    stackTrace: StackTrace.fromString('#0      first\n#1      second'),
    diagnostics: const {
      'time': '2026-09-12T10:23:45.123Z',
      'app version': '1.8.2+41',
      'provider': 'ollama',
      'model': 'qwen3:8b',
    },
  );

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFailureDetailDialog(context, report),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showFailureDetailDialog', () {
    testWidgets('presents the diagnostics, the cause and the stack trace', (
      tester,
    ) async {
      await pumpDialog(tester);

      final text = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byType(FailureDetailDialog),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;

      expect(text, contains('provider: ollama'));
      expect(text, contains('model: qwen3:8b'));
      expect(text, contains('app version: 1.8.2+41'));
      expect(
        text,
        contains('LlmAnalysisPartialFailure: 3 file(s) failed extraction'),
      );
      expect(text, contains('#0      first'));
    });

    testWidgets('makes the content scrollable', (tester) async {
      await pumpDialog(tester);

      expect(
        find.descendant(
          of: find.byType(FailureDetailDialog),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('copies the whole report and confirms it', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(call.arguments['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpDialog(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
      await tester.tap(find.text(l10n.failure_copyButton));
      await tester.pumpAndSettle();

      expect(copied, [renderFailureReport(report)]);
      expect(find.text(l10n.contextMenu_copiedToClipboard), findsOneWidget);
    });

    testWidgets('closes on the close button', (tester) async {
      await pumpDialog(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('ja'));

      await tester.tap(find.text(l10n.common_closeButton));
      await tester.pumpAndSettle();

      expect(find.byType(FailureDetailDialog), findsNothing);
    });
  });

  group('localization parity', () {
    testWidgets('every locale translates the dialog chrome', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(l10n.failure_detailTitle, isNotEmpty, reason: '$locale');
        expect(l10n.failure_detailsAction, isNotEmpty, reason: '$locale');
        expect(l10n.failure_copyButton, isNotEmpty, reason: '$locale');
        expect(l10n.common_closeButton, isNotEmpty, reason: '$locale');
      }
    });
  });
}
