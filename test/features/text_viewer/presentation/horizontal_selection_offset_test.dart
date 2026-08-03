import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Horizontal mode must report the selection start in PLAIN-TEXT coordinates
/// (ruby replaced by its base text), not in `SelectableText.rich` display
/// coordinates (where a ruby annotation is one U+FFFC character) and not in
/// raw-content coordinates (which still carry the `<ruby>` markup).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpRenderer(
    WidgetTester tester,
    String content,
  ) async {
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
              height: 600,
              width: 600,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(TextContentRenderer));
    return ProviderScope.containerOf(element);
  }

  /// Drives the renderer's own `onSelectionChanged` wiring without simulating
  /// a drag, which keeps the test independent of hit-test geometry.
  void reportSelection(WidgetTester tester, int start, int end) {
    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    selectable.onSelectionChanged!(
      TextSelection(baseOffset: start, extentOffset: end),
      SelectionChangedCause.drag,
    );
  }

  testWidgets('stores the selection offset for ruby-free content',
      (WidgetTester tester) async {
    const content = 'あいうえおかきくけこ';
    final container = await pumpRenderer(tester, content);

    reportSelection(tester, 3, 6);
    await tester.pump();

    final selection = container.read(selectedTextProvider);
    expect(selection?.text, 'えおか');
    expect(selection?.plainTextOffset, 3);
  });

  testWidgets('offset counts ruby as its base text, not as one character',
      (WidgetTester tester) async {
    // Raw content: 51 characters. Plain text: "彼は魔法を使った" (8 chars).
    // Display offsets: 彼(0) は(1) [ruby=魔法](2) を(3) 使(4) っ(5) た(6)
    const content =
        '彼は<ruby>魔法<rp>《</rp><rt>まほう</rt><rp>》</rp></ruby>を使った';
    final container = await pumpRenderer(tester, content);

    // Select "使った" — display offset 4, plain-text offset 5.
    reportSelection(tester, 4, 7);
    await tester.pump();

    final selection = container.read(selectedTextProvider);
    expect(selection?.text, '使った');
    expect(selection?.plainTextOffset, 5,
        reason: 'ruby contributes base.length (2), not 1 and not the markup');
  });

  testWidgets('offset is not a raw-content offset',
      (WidgetTester tester) async {
    const content =
        '彼は<ruby>魔法<rp>《</rp><rt>まほう</rt><rp>》</rp></ruby>を使った';
    final container = await pumpRenderer(tester, content);

    reportSelection(tester, 4, 7);
    await tester.pump();

    final offset = container.read(selectedTextProvider)!.plainTextOffset;
    // The raw content places "使" at index 48; using indexOf on the raw
    // content is exactly the bug this change removes.
    expect(content.indexOf('使'), isNot(offset));
    expect(offset, lessThan(content.length));
  });

  testWidgets('selection that starts inside ruby uses the ruby base start',
      (WidgetTester tester) async {
    const content =
        '彼は<ruby>魔法<rp>《</rp><rt>まほう</rt><rp>》</rp></ruby>を使った';
    final container = await pumpRenderer(tester, content);

    // Display offset 2 is the ruby WidgetSpan itself.
    reportSelection(tester, 2, 4);
    await tester.pump();

    final selection = container.read(selectedTextProvider);
    expect(selection?.text, '魔法を');
    expect(selection?.plainTextOffset, 2);
  });

  testWidgets('collapsed selection clears the stored selection',
      (WidgetTester tester) async {
    const content = 'あいうえおかきくけこ';
    final container = await pumpRenderer(tester, content);

    reportSelection(tester, 3, 6);
    await tester.pump();
    expect(container.read(selectedTextProvider), isNotNull);

    reportSelection(tester, 4, 4);
    await tester.pump();

    expect(container.read(selectedTextProvider), isNull);
  });
}
