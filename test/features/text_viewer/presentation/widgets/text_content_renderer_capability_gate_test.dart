import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the renderer's own wiring, not the menu builders it calls.
///
/// The builders are pure and covered directly, but they only omit an item when
/// the renderer withholds its label and callback. Removing those `ref.read`
/// checks would leave the builder tests green while putting the dictionary and
/// analysis actions back on an iPad, so the wiring needs a test that mounts the
/// real widget.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpRenderer(
    WidgetTester tester, {
    required bool ttsSupported,
    required bool llmSupported,
    TextDisplayMode mode = TextDisplayMode.horizontal,
    String content = 'アリスは旅に出た。',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          libraryPathProvider.overrideWithValue('/tmp/test/NovelViewer'),
          ttsSupportedProvider.overrideWithValue(ttsSupported),
          llmSummarySupportedProvider.overrideWithValue(llmSupported),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: TextContentRenderer(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (mode == TextDisplayMode.vertical) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TextContentRenderer)),
      );
      await container
          .read(displayModeProvider.notifier)
          .setMode(TextDisplayMode.vertical);
      await tester.pumpAndSettle();
    }
  }

  Future<List<String?>> toolbarLabels(
    WidgetTester tester, {
    required bool ttsSupported,
    required bool llmSupported,
  }) async {
    await pumpRenderer(
      tester,
      ttsSupported: ttsSupported,
      llmSupported: llmSupported,
    );

    // Select some text so the toolbar has something to act on, then ask the
    // renderer's own contextMenuBuilder what it would show.
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    editable.userUpdateTextEditingValue(
      editable.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 3),
      ),
      SelectionChangedCause.longPress,
    );
    await tester.pump();

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final menu =
        selectable.contextMenuBuilder!(
              tester.element(find.byType(EditableText)),
              editable,
            )
            as AdaptiveTextSelectionToolbar;

    return menu.buttonItems!.map((i) => i.label).toList();
  }

  testWidgets('both optional groups are offered on a desktop platform', (
    tester,
  ) async {
    final labels = await toolbarLabels(
      tester,
      ttsSupported: true,
      llmSupported: true,
    );

    expect(labels, contains('辞書追加'));
    expect(labels, contains('解析開始(ネタバレなし)'));
    expect(labels, contains('解析開始(ネタバレあり)'));
  });

  testWidgets('the dictionary item follows the TTS capability', (tester) async {
    final labels = await toolbarLabels(
      tester,
      ttsSupported: false,
      llmSupported: true,
    );

    expect(labels, isNot(contains('辞書追加')));
    expect(labels, contains('解析開始(ネタバレなし)'));
  });

  testWidgets('the analysis items follow the LLM capability', (tester) async {
    final labels = await toolbarLabels(
      tester,
      ttsSupported: true,
      llmSupported: false,
    );

    expect(labels, contains('辞書追加'));
    expect(labels, isNot(contains('解析開始(ネタバレなし)')));
    expect(labels, isNot(contains('解析開始(ネタバレあり)')));
  });

  testWidgets('an iPad is offered neither, but keeps the standard items', (
    tester,
  ) async {
    final labels = await toolbarLabels(
      tester,
      ttsSupported: false,
      llmSupported: false,
    );

    expect(labels, isNot(contains('辞書追加')));
    expect(labels, isNot(contains('解析開始(ネタバレなし)')));
    expect(labels, isNot(contains('解析開始(ネタバレあり)')));
    expect(labels, isNotEmpty);
  });

  /// Selects a range in vertical mode and opens its menu the way the desktop
  /// does — with a secondary tap. (Touch has no way to open this menu at all;
  /// that gap is tracked separately.) Returns the entry labels on screen.
  Future<List<String>> verticalMenuLabels(
    WidgetTester tester, {
    required bool ttsSupported,
    required bool llmSupported,
  }) async {
    await pumpRenderer(
      tester,
      ttsSupported: ttsSupported,
      llmSupported: llmSupported,
      mode: TextDisplayMode.vertical,
      content: 'あいうえおかきくけこ',
    );

    final from = tester.getCenter(find.text('い'));
    final to = tester.getCenter(find.text('え'));
    await tester.timedDragFrom(
      from,
      to - from,
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(to, buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();

    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
  }

  testWidgets('vertical mode offers both groups on a desktop platform', (
    tester,
  ) async {
    final labels = await verticalMenuLabels(
      tester,
      ttsSupported: true,
      llmSupported: true,
    );

    expect(labels, contains('コピー'));
    expect(labels, contains('辞書追加'));
    expect(labels, contains('解析開始(ネタバレなし)'));
    expect(labels, contains('解析開始(ネタバレあり)'));
  });

  testWidgets('vertical mode withholds both groups on an iPad', (tester) async {
    final labels = await verticalMenuLabels(
      tester,
      ttsSupported: false,
      llmSupported: false,
    );

    expect(labels, contains('コピー'));
    expect(labels, isNot(contains('辞書追加')));
    expect(labels, isNot(contains('解析開始(ネタバレなし)')));
    expect(labels, isNot(contains('解析開始(ネタバレあり)')));
  });
}
