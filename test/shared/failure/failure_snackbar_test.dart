import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/failure/failure_detail_dialog.dart';
import 'package:novel_viewer/shared/failure/failure_report.dart';
import 'package:novel_viewer/shared/failure/failure_snackbar.dart';

/// Hosts the trigger inside a child that the test can remove while leaving the
/// Scaffold — and therefore the snackbar — in place.
class _Host extends StatefulWidget {
  const _Host({required this.report});

  final FailureReport report;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _triggerVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_triggerVisible)
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showFailureSnackBar(context, widget.report),
                child: const Text('go'),
              ),
            ),
          TextButton(
            onPressed: () => setState(() => _triggerVisible = false),
            child: const Text('hide'),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('formatFailureSnackBarBody', () {
    test('appends the raw cause to the localized headline', () {
      expect(
        formatFailureSnackBarBody(
          const FailureReport(
            headline: '合成に失敗しました',
            cause: 'unsupported WAV encoding (need PCM16, PCM24, or float32)',
          ),
        ),
        '合成に失敗しました: unsupported WAV encoding '
        '(need PCM16, PCM24, or float32)',
      );
    });

    test('returns the headline alone when there is no cause', () {
      expect(
        formatFailureSnackBarBody(
          const FailureReport(headline: 'Synthesis failed'),
        ),
        'Synthesis failed',
      );
    });

    test('treats a blank cause as no cause', () {
      expect(
        formatFailureSnackBarBody(
          const FailureReport(headline: 'Synthesis failed', cause: '   '),
        ),
        'Synthesis failed',
      );
    });

    test('trims surrounding whitespace from the cause', () {
      expect(
        formatFailureSnackBarBody(
          const FailureReport(
            headline: '合成失败',
            cause: '  could not open audio input  ',
          ),
        ),
        '合成失败: could not open audio input',
      );
    });
  });

  Future<String> jaLabel(String Function(AppLocalizations) pick) async {
    return pick(await AppLocalizations.delegate.load(const Locale('ja')));
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: home,
      ),
    );
  }

  Future<void> pumpAndShow(
    WidgetTester tester, {
    required String headline,
    String? cause,
  }) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFailureSnackBar(
              context,
              FailureReport(headline: headline, cause: cause),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    // Settle the entrance animation: until it finishes the bar sits below the
    // viewport and taps on it miss.
    await tester.pumpAndSettle();
  }

  group('showFailureSnackBar body', () {
    testWidgets('joins the localized headline with the raw cause', (
      tester,
    ) async {
      await pumpAndShow(
        tester,
        headline: '合成に失敗しました',
        cause: 'unsupported WAV encoding (need PCM16, PCM24, or float32)',
      );

      expect(
        find.text(
          '合成に失敗しました: unsupported WAV encoding '
          '(need PCM16, PCM24, or float32)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the headline alone when there is no cause', (
      tester,
    ) async {
      await pumpAndShow(tester, headline: 'Synthesis failed');

      expect(find.text('Synthesis failed'), findsOneWidget);
    });
  });

  group('showFailureSnackBar lifetime', () {
    testWidgets('stays visible long past the default duration', (tester) async {
      await pumpAndShow(tester, headline: '解析に失敗しました');

      await tester.pump(const Duration(seconds: 30));

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('offers a close affordance that dismisses it', (tester) async {
      await pumpAndShow(tester, headline: '解析に失敗しました');

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.showCloseIcon, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(FailureDetailDialog), findsNothing);
    });

    testWidgets('carries exactly one action, the details action', (
      tester,
    ) async {
      await pumpAndShow(tester, headline: '解析に失敗しました');

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.action, isNotNull);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(SnackBarAction),
        ),
        findsOneWidget,
      );
      expect(bar.action!.label, await jaLabel((l) => l.failure_detailsAction));
    });

    testWidgets('replaces the previous failure instead of queueing behind it', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showFailureSnackBar(
                    context,
                    const FailureReport(headline: 'first failure'),
                  ),
                  child: const Text('first'),
                ),
                TextButton(
                  onPressed: () => showFailureSnackBar(
                    context,
                    const FailureReport(headline: 'second failure'),
                  ),
                  child: const Text('second'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('second'));
      await tester.pumpAndSettle();

      expect(find.text('second failure'), findsOneWidget);
      expect(find.text('first failure'), findsNothing);
    });
  });

  group('showFailureSnackBar details action', () {
    testWidgets('opens the detail dialog', (tester) async {
      await pumpAndShow(tester, headline: '解析に失敗しました', cause: 'boom');

      await tester.tap(
        find.text(await jaLabel((l) => l.failure_detailsAction)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FailureDetailDialog), findsOneWidget);
    });

    testWidgets('still opens after the triggering widget is disposed', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const _Host(report: FailureReport(headline: '解析に失敗しました')),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('hide'));
      await tester.pumpAndSettle();

      expect(find.text('go'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.tap(
        find.text(await jaLabel((l) => l.failure_detailsAction)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FailureDetailDialog), findsOneWidget);
    });
  });
}
