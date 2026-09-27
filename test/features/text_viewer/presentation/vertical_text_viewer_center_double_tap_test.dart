import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  testWidgets('the viewer relays a center double tap from its page', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: VerticalTextViewer(
                segments: const [PlainTextSegment('昨日アリスが来た。')],
                baseStyle: const TextStyle(fontSize: 14.0),
                onCenterDoubleTap: () => calls++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Below the single column of text, in the middle of the page.
    final page = tester.getRect(find.byType(VerticalTextPage));
    final target = Offset(page.center.dx, page.bottom - 40);
    await tester.tapAt(target);
    await tester.pump();
    await tester.tapAt(target);
    await tester.pump();

    expect(calls, 1);
  });
}
