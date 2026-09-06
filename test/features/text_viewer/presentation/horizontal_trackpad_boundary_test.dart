import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

/// A macOS trackpad swipe reaches Flutter as `PointerPanZoomUpdateEvent`, which
/// is not a `PointerSignalEvent` and so never reaches `onPointerSignal` — the
/// only place the horizontal viewer used to look for boundary input. Scrolling
/// worked (Scrollable accepts trackpad through its drag recognizers) but
/// episode switching did not.
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

  final longContent = List.generate(
    200,
    (i) => 'これは ${i + 1} 行目の内容です。',
  ).join('\n');

  ProviderContainer makeContainer({
    AdjacentFiles adjacent = const AdjacentFiles(
      prev: _prevFile,
      next: _nextFile,
    ),
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        displayModeProvider.overrideWith(
          () => _StubDisplayMode(TextDisplayMode.horizontal),
        ),
        adjacentFilesProvider.overrideWithValue(adjacent),
        episodeNavigationControllerProvider.overrideWith(
          (ref) => _SpyEpisodeNav(ref),
        ),
      ],
    );
  }

  Widget wrap({required ProviderContainer container, required String content}) {
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

  Finder outerScrollable() => find
      .descendant(
        of: find.byType(TextContentRenderer),
        matching: find.byType(Scrollable),
      )
      .first;

  _SpyEpisodeNav spyOf(ProviderContainer c) =>
      c.read(episodeNavigationControllerProvider) as _SpyEpisodeNav;

  /// One two-finger trackpad swipe. [dy] is negative to push toward the end.
  Future<void> trackpadSwipe(WidgetTester tester, double dy) async {
    final center = tester.getCenter(find.byType(TextContentRenderer));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.trackpad,
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(0, dy / 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Runs [body] with the platform that gives BouncingScrollPhysics, which is
  /// what the user's macOS build uses. The override has to be cleared inside
  /// the test body — the framework checks it before tearDown runs.
  Future<void> onMacOS(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('a trackpad swipe past the end arms the hint', (tester) async {
    await onMacOS(() async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      expect(state.position.physics, isA<BouncingScrollPhysics>());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      await trackpadSwipe(tester, -150);

      expect(spyOf(container).next, 0, reason: 'the first swipe only arms');
      expect(find.textContaining('003.txt'), findsOneWidget);
    });
  });

  testWidgets('a second trackpad swipe confirms the episode switch', (
    tester,
  ) async {
    await onMacOS(() async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      await trackpadSwipe(tester, -150);
      await tester.pump(const Duration(milliseconds: 350));
      await trackpadSwipe(tester, -150);

      expect(spyOf(container).next, 1);
      expect(spyOf(container).prev, 0);
    });
  });

  testWidgets('a trackpad swipe past the start goes to the previous episode', (
    tester,
  ) async {
    await onMacOS(() async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      // Mounts at the top, so a downward swipe pushes past the start.
      await trackpadSwipe(tester, 150);
      expect(spyOf(container).prev, 0);

      await tester.pump(const Duration(milliseconds: 350));
      await trackpadSwipe(tester, 150);

      expect(spyOf(container).prev, 1);
    });
  });

  testWidgets('a trackpad swipe in mid-file does not arm anything', (
    tester,
  ) async {
    await onMacOS(() async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent / 2);
      await tester.pump();

      await trackpadSwipe(tester, -60);
      await tester.pump(const Duration(milliseconds: 350));
      await trackpadSwipe(tester, -60);

      expect(spyOf(container).next, 0);
      expect(find.textContaining('003.txt'), findsNothing);
    });
  });

  testWidgets('the bounce-back does not erase the hint the swipe armed', (
    tester,
  ) async {
    await onMacOS(() async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      // trackpadSwipe settles the ballistic bounce before returning, so the
      // hint surviving here means the bounce frames were ignored.
      await trackpadSwipe(tester, -150);

      expect(find.textContaining('003.txt'), findsOneWidget);
      expect(state.position.pixels, state.position.maxScrollExtent);
    });
  });

  testWidgets('no adjacent file means a trackpad swipe does nothing', (
    tester,
  ) async {
    await onMacOS(() async {
      final container = makeContainer(
        adjacent: const AdjacentFiles(prev: _prevFile, next: null),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(wrap(container: container, content: longContent));
      await tester.pumpAndSettle();

      final state = tester.state<ScrollableState>(outerScrollable());
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();

      await trackpadSwipe(tester, -150);
      await tester.pump(const Duration(milliseconds: 350));
      await trackpadSwipe(tester, -150);

      expect(spyOf(container).next, 0);
      expect(find.textContaining('003.txt'), findsNothing);
    });
  });
}

class _StubDisplayMode extends DisplayModeNotifier {
  final TextDisplayMode _initial;
  _StubDisplayMode(this._initial);

  @override
  TextDisplayMode build() => _initial;
}
