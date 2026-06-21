import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap({
  required ProviderContainer container,
  required String content,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 200,
          child: TextContentRenderer(content: content),
        ),
      ),
    ),
  );
}

void main() {
  // A content blob tall enough that horizontal-mode scrolling is meaningful.
  final longContent =
      List.generate(200, (i) => 'これは ${i + 1} 行目の内容です。')
          .join('\n');

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        displayModeProvider.overrideWith(
            () => _StubDisplayMode(TextDisplayMode.horizontal)),
      ],
    );
    return container;
  }

  group('TextContentRenderer file-entry intent consumption (horizontal mode)',
      () {
    testWidgets('intent=fromStart leaves scroll at offset 0', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromStart);

      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      // The outer scrollable belongs to SingleChildScrollView; nested ones
      // (e.g. inside SelectableText.rich) appear later. Pick the first.
      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final position =
          tester.state<ScrollableState>(scrollable).position.pixels;
      expect(position, 0.0);
      // Intent should have been consumed and cleared.
      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    testWidgets('null intent leaves scroll at offset 0', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      // No intent.

      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      // The outer scrollable belongs to SingleChildScrollView; nested ones
      // (e.g. inside SelectableText.rich) appear later. Pick the first.
      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final position =
          tester.state<ScrollableState>(scrollable).position.pixels;
      expect(position, 0.0);
      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    testWidgets('intent=fromEnd jumps to maxScrollExtent', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);

      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      // The outer scrollable belongs to SingleChildScrollView; nested ones
      // (e.g. inside SelectableText.rich) appear later. Pick the first.
      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      expect(state.position.pixels, state.position.maxScrollExtent,
          reason: 'fromEnd intent should scroll to the bottom');
      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    testWidgets(
        'vertical mode does not latch _jumpToEndPending — no leak on mode '
        'toggle to horizontal', (tester) async {
      // The bug: in vertical mode TextContentRenderer used to consume the
      // intent and set _jumpToEndPending, which only fires inside the
      // horizontal-mode build branch. Toggling to horizontal later would
      // unexpectedly scroll to maxScrollExtent.
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          displayModeProvider.overrideWith(
              () => _StubDisplayMode(TextDisplayMode.vertical)),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);

      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      // Toggle to horizontal — if the bug were present, this rebuild would
      // observe _jumpToEndPending=true and schedule a jumpTo(maxScrollExtent).
      await container
          .read(displayModeProvider.notifier)
          .setMode(TextDisplayMode.horizontal);
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      expect(state.position.pixels, 0.0,
          reason:
              'After a vertical-mode mount, toggling to horizontal must not '
              'scroll to the bottom (no _jumpToEndPending leak)');
    });

    testWidgets(
        'intent=fromStart on content swap resets scroll to 0 (regression: '
        'previous-file scroll position must not leak into the next file)',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Mount, then manually scroll to the bottom — simulating a user
      // parked at end-of-file before pressing "Next →".
      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
      expect(state.position.pixels, greaterThan(0));

      // Simulate "Next →" click: set fromStart intent, then swap content.
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromStart);
      final newContent = List.generate(
              200, (i) => '別ファイル ${i + 1} 行目')
          .join('\n');
      await tester.pumpWidget(
          _wrap(container: container, content: newContent));
      await tester.pumpAndSettle();

      final state2 = tester.state<ScrollableState>(find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first);
      expect(state2.position.pixels, 0.0,
          reason:
              'fromStart intent after content swap must reset scroll to top — '
              'otherwise the previous file\'s scroll offset leaks into the '
              'new file and the user appears in the middle of it');
      expect(container.read(pendingFileEntryIntentProvider), isNull);
    });

    testWidgets(
        'null intent on content swap resets scroll to 0 (regression: '
        'file-browser click must not leak previous file scroll offset)',
        (tester) async {
      // Mirrors the fromStart-on-content-swap regression test but for the
      // case where no intent was ever set — i.e., the user picks a file
      // directly from the file browser. The spec
      // (specs/text-viewer/spec.md: "通常選択時のスクロール位置（横書き）")
      // requires offset 0 on file swap when intent is null, so the previous
      // file's offset must not leak through the persisted ScrollController.
      final container = makeContainer();
      addTearDown(container.dispose);

      // Mount, then manually scroll into the middle of the file — the user
      // is mid-reading when they click a different file in the browser.
      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      state.position.jumpTo(state.position.maxScrollExtent / 2);
      await tester.pump();
      expect(state.position.pixels, greaterThan(0));
      // Intent is left untouched (null) — this is the file-browser-click path.
      expect(container.read(pendingFileEntryIntentProvider), isNull);

      // Simulate the file-browser click: content swap with no intent.
      final newContent = List.generate(
              200, (i) => '別ファイル ${i + 1} 行目')
          .join('\n');
      await tester.pumpWidget(
          _wrap(container: container, content: newContent));
      await tester.pumpAndSettle();

      final state2 = tester.state<ScrollableState>(find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first);
      expect(state2.position.pixels, 0.0,
          reason:
              'A content swap with no pending intent (file browser click) '
              'must reset scroll to top — otherwise the previous file\'s '
              'offset leaks through the persisted ScrollController and the '
              'user appears in the middle of the new file');
    });

    testWidgets(
        '_jumpToEndPending is cleared after a single build (no leak into '
        'later rebuilds)', (tester) async {
      // After fromEnd is consumed and the scroll jumped to the bottom, a
      // later rebuild with no fresh intent must not jump again — the flag
      // must have been cleared in the original build, regardless of which
      // branch of the if/else if chain ultimately fired.
      final container = makeContainer();
      addTearDown(container.dispose);
      container
          .read(pendingFileEntryIntentProvider.notifier)
          .set(FileEntryStartIntent.fromEnd);

      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      // First build jumped to end as designed.
      expect(state.position.pixels, state.position.maxScrollExtent);

      // Manually scroll back to top, then pump a fresh build (no intent
      // change). The flag must NOT re-fire and pull us back to the bottom.
      state.position.jumpTo(0);
      await tester.pump();
      await tester.pumpWidget(_wrap(
          container: container, content: longContent));
      await tester.pumpAndSettle();

      final state2 = tester.state<ScrollableState>(find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first);
      expect(state2.position.pixels, 0.0,
          reason:
              '_jumpToEndPending must be cleared after the first build so a '
              'later rebuild does not jump again');
    });
  });
}

class _StubDisplayMode extends DisplayModeNotifier {
  final TextDisplayMode _initial;
  _StubDisplayMode(this._initial);

  @override
  TextDisplayMode build() => _initial;
}
