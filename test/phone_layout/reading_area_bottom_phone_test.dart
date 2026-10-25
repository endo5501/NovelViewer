import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/providers/adjacent_files_provider.dart';
import 'package:novel_viewer/features/episode_navigation/providers/episode_navigation_controller.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/vertical_text_page.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/phone_display.dart';

/// What the reading area shows along its bottom edge, on the portrait display
/// of an iPhone 16: it must stay above the home indicator (design D5).
class _StubDisplayMode extends DisplayModeNotifier {
  _StubDisplayMode(this._mode);
  final TextDisplayMode _mode;
  @override
  TextDisplayMode build() => _mode;
}

/// Keeps the boundary gesture from swapping the selected file, so the hint
/// stays on screen for the assertions.
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

  const visibleBottom = 852 - kPhoneBottomInset;

  Future<ProviderContainer> pumpReadingArea(
    WidgetTester tester,
    TextDisplayMode mode, {
    String? content,
  }) async {
    usePhoneDisplay(tester);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        displayModeProvider.overrideWith(() => _StubDisplayMode(mode)),
        adjacentFilesProvider.overrideWithValue(
          const AdjacentFiles(prev: _prevFile, next: _nextFile),
        ),
        episodeNavigationControllerProvider.overrideWith(
          (ref) => _SpyEpisodeNav(ref),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The reading area fills the body the way it does on the home screen,
    // which keeps the bottom safe area in its MediaQuery.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(),
            body: TextContentRenderer(content: content ?? longContent),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  void expectAboveHomeIndicator(WidgetTester tester, Finder finder) {
    expect(finder, findsOneWidget);
    final bottom = tester.getRect(finder).bottom;
    expect(
      bottom,
      lessThanOrEqualTo(visibleBottom),
      reason:
          'it ends at $bottom, inside the home indicator below $visibleBottom',
    );
  }

  testWidgets('the vertical page indicator sits above the home indicator', (
    tester,
  ) async {
    await pumpReadingArea(tester, TextDisplayMode.vertical);

    expectAboveHomeIndicator(tester, find.textContaining(RegExp(r'^1 / \d+')));
  });

  testWidgets(
    'the horizontal next-episode hint sits above the home indicator',
    (tester) async {
      await pumpReadingArea(tester, TextDisplayMode.horizontal);

      final scrollable = find
          .descendant(
            of: find.byType(TextContentRenderer),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expectAboveHomeIndicator(tester, find.textContaining('003.txt'));
    },
  );

  testWidgets(
    'a vertical page fills every column of a paragraph but its last',
    (tester) async {
      // One paragraph several columns long. The page is paginated for a column
      // height; if the page is then given less height than that, the run of
      // characters wraps early and leaves short columns in the middle. Whether
      // the shortfall shows depends on the slack the font size leaves, so a
      // range of sizes is tried.
      final paragraph = List.filled(30, 'あいうえおかきくけこ').join();
      final container = await pumpReadingArea(
        tester,
        TextDisplayMode.vertical,
        content: paragraph,
      );

      List<int> columnSizes() {
        final counts = <double, int>{};
        for (final element
            in find
                .descendant(
                  of: find.byType(VerticalTextPage),
                  matching: find.byType(Text),
                )
                .evaluate()) {
          final box = element.renderObject! as RenderBox;
          final x = box.localToGlobal(box.size.center(Offset.zero)).dx;
          counts.update(x.roundToDouble(), (n) => n + 1, ifAbsent: () => 1);
        }
        // Right to left, as the columns are read.
        return (counts.entries.toList()..sort((a, b) => b.key.compareTo(a.key)))
            .map((e) => e.value)
            .toList();
      }

      final broken = <String>[];
      for (var size = 12.0; size <= 32; size++) {
        container.read(fontSizeProvider.notifier).previewFontSize(size);
        await tester.pumpAndSettle();
        final sizes = columnSizes();
        // Every column on the page but the last is full and so the same length.
        if (sizes.length > 1 &&
            sizes.take(sizes.length - 1).toSet().length > 1) {
          broken.add('font size $size: $sizes');
        }
      }

      expect(broken, isEmpty);
    },
  );
}
