import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/presentation/tts_failure_snackbar.dart';

void main() {
  Future<void> pumpAndShow(
    WidgetTester tester, {
    required String headline,
    String? reason,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTtsFailureSnackBar(
              context,
              headline: headline,
              reason: reason,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  group('showTtsFailureSnackBar', () {
    testWidgets('joins the localized headline with the native reason',
        (tester) async {
      await pumpAndShow(
        tester,
        headline: '合成に失敗しました',
        reason: 'unsupported WAV encoding (need PCM16, PCM24, or float32)',
      );

      expect(
        find.text('合成に失敗しました: unsupported WAV encoding '
            '(need PCM16, PCM24, or float32)'),
        findsOneWidget,
      );
    });

    testWidgets('shows the headline alone when there is no reason',
        (tester) async {
      await pumpAndShow(tester, headline: 'Synthesis failed');

      expect(find.text('Synthesis failed'), findsOneWidget);
    });

    testWidgets('keeps the long-read duration', (tester) async {
      await pumpAndShow(tester, headline: 'x', reason: 'y');

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 8),
          reason: 'native causes run long; 4s is not enough to read one');
    });
  });
}
