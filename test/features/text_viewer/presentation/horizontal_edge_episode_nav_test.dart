import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/episode_navigation/providers/episode_navigation_controller.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spy controller that records boundary navigation calls instead of actually
/// swapping the selected file. Lets the tests assert that an edge gesture
/// routed to next/previous episode navigation.
class _SpyEpisodeNav extends EpisodeNavigationController {
  _SpyEpisodeNav(super.ref);
  int next = 0;
  int prev = 0;
  @override
  void navigateToNext() => next++;
  @override
  void navigateToPrevious() => prev++;
}

const _prevFile = FileEntry(name: '001.txt', path: '/n/001.txt');
const _nextFile = FileEntry(name: '003.txt', path: '/n/003.txt');

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // Long enough that horizontal mode is scrollable.
  final longContent =
      List.generate(200, (i) => 'これは ${i + 1} 行目の内容です。').join('\n');

  ProviderContainer makeContainer({
    AdjacentFiles adjacent =
        const AdjacentFiles(prev: _prevFile, next: _nextFile),
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        displayModeProvider
            .overrideWith(() => _StubDisplayMode(TextDisplayMode.horizontal)),
        adjacentFilesProvider.overrideWithValue(adjacent),
        episodeNavigationControllerProvider
            .overrideWith((ref) => _SpyEpisodeNav(ref)),
      ],
    );
  }

  Widget wrap({
    required ProviderContainer container,
    required String content,
    Widget? sibling,
  }) {
    final viewer = SizedBox(
      width: 400,
      height: 200,
      child: TextContentRenderer(content: content),
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: sibling == null
              ? viewer
              : Column(children: [sibling, Expanded(child: viewer)]),
        ),
      ),
    );
  }

  Finder outerScrollable() => find
      .descendant(
        of: find.byType(TextContentRenderer),
        matching: find.byType(Scrollable),
      )
      .first;

  _SpyEpisodeNav spyOf(ProviderContainer c) =>
      c.read(episodeNavigationControllerProvider) as _SpyEpisodeNav;

  Future<void> sendWheel(WidgetTester tester, double dy) async {
    final center = tester.getCenter(find.byType(TextContentRenderer));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pump();
  }

  group('horizontal edge episode navigation — cursor keys', () {
    testWidgets('arrow down at scroll-bottom navigates to next episode',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(spyOf(container).next, 1);
      expect(spyOf(container).prev, 0);
    });

    testWidgets('arrow up at scroll-top navigates to previous episode',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      // Initial mount is already at top (offset 0).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(spyOf(container).prev, 1);
      expect(spyOf(container).next, 0);
    });

    testWidgets('arrow down in the middle scrolls without navigating',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent / 2);
      await tester.pump();
      final before = state.position.pixels;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(spyOf(container).next, 0,
          reason: 'Mid-scroll arrow down must page within the file, not '
              'switch episodes');
      expect(state.position.pixels, greaterThan(before));
    });

    testWidgets('arrow down at bottom with no next file is a no-op',
        (tester) async {
      final container = makeContainer(
          adjacent: const AdjacentFiles(prev: _prevFile, next: null));
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(spyOf(container).next, 0);
    });

    testWidgets('arrow up at top with no previous file is a no-op',
        (tester) async {
      final container = makeContainer(
          adjacent: const AdjacentFiles(prev: null, next: _nextFile));
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(spyOf(container).prev, 0);
    });

    testWidgets('arrow key does not navigate when focus is elsewhere',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(
        container: container,
        content: longContent,
        sibling: const TextField(),
      ));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      // Move focus away from the viewer to the sibling text field.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(spyOf(container).next, 0,
          reason: 'With focus on the file browser / another widget, the '
              'viewer must not consume the arrow key for episode navigation');
    });
  });

  group('horizontal edge episode navigation — mouse wheel', () {
    testWidgets('wheel down at scroll-bottom navigates to next episode',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      await sendWheel(tester, 60);

      expect(spyOf(container).next, 1);
    });

    testWidgets('wheel up at scroll-top navigates to previous episode',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      await sendWheel(tester, -60);

      expect(spyOf(container).prev, 1);
    });

    testWidgets('wheel in the middle does not navigate', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent / 2);
      await tester.pump();

      await sendWheel(tester, 60);

      expect(spyOf(container).next, 0);
    });
  });

  group('horizontal edge episode navigation — runaway cooldown', () {
    testWidgets('wheel burst at bottom navigates only once', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      // Two wheel ticks back-to-back without advancing the simulated clock —
      // both fall inside the cooldown window.
      await sendWheel(tester, 60);
      await sendWheel(tester, 60);

      expect(spyOf(container).next, 1,
          reason: 'A burst of wheel events must advance at most one episode');
    });

    testWidgets('navigation works again after the cooldown elapses',
        (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      await sendWheel(tester, 60);
      expect(spyOf(container).next, 1);

      // Let the cooldown expire, then the boundary gesture works again.
      await tester.pump(const Duration(seconds: 1));
      await sendWheel(tester, 60);

      expect(spyOf(container).next, 2);
    });

    testWidgets(
        'short (single-screen) episode: wheel burst does not run away',
        (tester) async {
      // maxScrollExtent == 0 → simultaneously at top and bottom. A continued
      // wheel burst must still only advance one episode per cooldown window.
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
          wrap(container: container, content: '一行だけのテキスト。'));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      expect(state.position.maxScrollExtent, 0);

      await sendWheel(tester, 60);
      await sendWheel(tester, 60);
      await sendWheel(tester, 60);

      expect(spyOf(container).next, 1,
          reason: 'On a one-screen episode the cooldown must prevent a wheel '
              'burst from skipping multiple episodes');
    });
  });
}

class _StubDisplayMode extends DisplayModeNotifier {
  final TextDisplayMode _initial;
  _StubDisplayMode(this._initial);

  @override
  TextDisplayMode build() => _initial;
}
