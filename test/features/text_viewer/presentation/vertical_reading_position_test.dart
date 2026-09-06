import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_viewer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import '../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('fromEnd reports the destination page offset', (tester) async {
    final container = ProviderContainer();
    container
        .read(pendingFileEntryIntentProvider.notifier)
        .set(FileEntryStartIntent.fromEnd);
    final reports = <int>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: LocalizedMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 350,
              height: 250,
              child: VerticalTextViewer(
                segments: parseRubyText(
                  List.filled(100, 'abcdefghij\n').join(),
                ),
                baseStyle: const TextStyle(fontSize: 16),
                onBodyPositionChanged: reports.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = tester.widget<VerticalTextPage>(
      find.byType(VerticalTextPage).first,
    );
    expect(page.pageStartTextOffset, greaterThan(500));
    expect(reports.last, page.pageStartTextOffset);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'bookmark jump reports its displayed page rather than old anchor',
    (tester) async {
      final segments = parseRubyText(
        List.generate(100, (i) => 'line$i text').join('\n'),
      );
      final reports = <int>[];
      Future<void> pump(int? line) async {
        await tester.pumpWidget(
          ProviderScope(
            child: LocalizedMaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 350,
                  height: 250,
                  child: VerticalTextViewer(
                    segments: segments,
                    baseStyle: const TextStyle(fontSize: 16),
                    bodyOffset: 50,
                    targetLineNumber: line,
                    onBodyPositionChanged: reports.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(null);
      await pump(80);
      final page = tester.widget<VerticalTextPage>(
        find.byType(VerticalTextPage).first,
      );
      expect(page.pageStartTextOffset, greaterThan(500));
      expect(reports.last, page.pageStartTextOffset);
    },
  );

  testWidgets('vertical restores a body anchor across width changes', (
    tester,
  ) async {
    final segments = parseRubyText(
      List.filled(
        100,
        'abc\u{1f600}<ruby>de<rt>reading</rt></ruby>\n\nfgh',
      ).join(),
    );
    final reports = <int>[];
    Future<void> pump(double width) async {
      await tester.pumpWidget(
        ProviderScope(
          child: LocalizedMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                height: 250,
                child: VerticalTextViewer(
                  segments: segments,
                  baseStyle: const TextStyle(fontSize: 16),
                  bodyOffset: 500,
                  onBodyPositionChanged: reports.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(400);
    expect(reports.last, 500);
    await pump(250);
    expect(reports.last, 500);
    await pump(400);
    expect(reports.last, 500);
  });
}
