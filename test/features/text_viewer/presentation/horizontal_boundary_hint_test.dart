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

/// Keeps the boundary gesture from actually swapping the selected file, so the
/// hint stays on screen for the assertions.
class _SpyEpisodeNav extends EpisodeNavigationController {
  _SpyEpisodeNav(super.ref);
  @override
  void navigateToNext() {}
  @override
  void navigateToPrevious() {}
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

  Future<void> armNextHint(WidgetTester tester) async {
    final state = tester.state<ScrollableState>(outerScrollable());
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
  }

  testWidgets('the next-episode hint names the adjacent file', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container: container, content: longContent));
    await tester.pumpAndSettle();

    await armNextHint(tester);

    expect(find.textContaining('003.txt'), findsOneWidget);
  });

  testWidgets('the previous-episode hint names the adjacent file', (
    tester,
  ) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container: container, content: longContent));
    await tester.pumpAndSettle();

    // Mounts at the top, so an "up" input is already at the boundary.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.textContaining('001.txt'), findsOneWidget);
  });

  testWidgets('no hint is rendered while idle', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container: container, content: longContent));
    await tester.pumpAndSettle();

    expect(find.textContaining('003.txt'), findsNothing);
    expect(find.textContaining('001.txt'), findsNothing);
  });

  testWidgets('the hint disappears when the window times out', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container: container, content: longContent));
    await tester.pumpAndSettle();

    await armNextHint(tester);
    expect(find.textContaining('003.txt'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));

    expect(find.textContaining('003.txt'), findsNothing);
  });

  testWidgets('an in-file page move hides the hint', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container: container, content: longContent));
    await tester.pumpAndSettle();

    await armNextHint(tester);
    expect(find.textContaining('003.txt'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.textContaining('003.txt'), findsNothing);
  });

  testWidgets('no hint when there is no adjacent file in that direction', (
    tester,
  ) async {
    final container = makeContainer(
      adjacent: const AdjacentFiles(prev: _prevFile, next: null),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container: container, content: longContent));
    await tester.pumpAndSettle();

    await armNextHint(tester);

    expect(find.textContaining('003.txt'), findsNothing);
    expect(
      find.textContaining('001.txt'),
      findsNothing,
      reason: 'A downward boundary input must not surface the previous hint',
    );
  });

  testWidgets('showing the hint does not move the body or its scroll extent', (
    tester,
  ) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(wrap(container: container, content: longContent));
    await tester.pumpAndSettle();

    final state = tester.state<ScrollableState>(outerScrollable());
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pump();
    final pixelsBefore = state.position.pixels;
    final extentBefore = state.position.maxScrollExtent;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.textContaining('003.txt'), findsOneWidget);

    expect(state.position.pixels, pixelsBefore);
    expect(state.position.maxScrollExtent, extentBefore);
  });
}

class _StubDisplayMode extends DisplayModeNotifier {
  final TextDisplayMode _initial;
  _StubDisplayMode(this._initial);

  @override
  TextDisplayMode build() => _initial;
}
