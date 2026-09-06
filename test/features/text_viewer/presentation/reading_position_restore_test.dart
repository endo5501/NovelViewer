import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_position_writer.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_position_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';
import 'package:novel_viewer/features/episode_navigation/providers/pending_file_entry_intent_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/bookmark/providers/bookmark_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

void main() {
  testWidgets('TTS follow wins over a delayed reading restoration', (
    tester,
  ) async {
    final deferred = Completer<ReadingProgress?>();
    final harness = await _reader(tester, deferred.future);
    harness
        .read(ttsHighlightRangeProvider.notifier)
        .set(const TextRange(start: 50, end: 60));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final followed = scroll.position.pixels;
    deferred.complete(_progress());
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, closeTo(followed, 1));
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('manual paging cancels a delayed restoration', (tester) async {
    final deferred = Completer<ReadingProgress?>();
    final saves = <PositionSnapshot>[];
    final harness = await _reader(tester, deferred.future, saves: saves);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final position = scroll.position.pixels;
    deferred.complete(_progress());
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, closeTo(position, 1));
    await tester.pump(const Duration(seconds: 2));
    expect(saves.last.offset, inExclusiveRange(0, 1000));
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('a bookmark jump wins over a delayed restoration', (
    tester,
  ) async {
    final deferred = Completer<ReadingProgress?>();
    final harness = await _reader(tester, deferred.future);
    harness.read(bookmarkJumpLineProvider.notifier).jump(1);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final jumped = scroll.position.pixels;
    // The saved offset (1000) lands well past 100px, so a restoration that
    // ignored the bookmark would be visible as a move away from the jump.
    deferred.complete(_progress());
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, closeTo(jumped, 1));
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('a selected search match wins over a delayed restoration', (
    tester,
  ) async {
    final deferred = Completer<ReadingProgress?>();
    final harness = await _reader(tester, deferred.future);
    harness
        .read(selectedSearchMatchProvider.notifier)
        .select(filePath: '/book/a.txt', lineNumber: 1, query: 'abcde');
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final matched = scroll.position.pixels;
    deferred.complete(_progress());
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, closeTo(matched, 1));
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('explicit fromStart wins over saved body offset', (tester) async {
    final saves = <PositionSnapshot>[];
    final harness = await _reader(
      tester,
      Future.value(_progress()),
      fromStart: true,
      saves: saves,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      0,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(saves.last.offset, 0);
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('switching writing modes keeps the saved logical body position', (
    tester,
  ) async {
    final saves = <PositionSnapshot>[];
    final harness = await _reader(
      tester,
      Future.value(_progress()),
      saves: saves,
    );
    await tester.pumpAndSettle();
    harness
        .read(displayModeProvider.notifier)
        .setMode(TextDisplayMode.vertical);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(saves.last.offset, 1000);
    harness
        .read(displayModeProvider.notifier)
        .setMode(TextDisplayMode.horizontal);
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(100),
    );
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('restoring then re-capturing is a fixed point (no line creep)', (
    tester,
  ) async {
    // Capture converts a scroll offset into a body offset by subtracting the
    // scroll view's 16px padding; restore must add it back. If it does not,
    // every reopen resolves the line above the saved one and the position
    // creeps backwards one line per session.
    final first = await _restoreThenCapture(tester, 1000);
    final second = await _restoreThenCapture(tester, first);
    expect(second, first);
  });

  testWidgets('repeated layout changes never shift the anchor', (
    tester,
  ) async {
    // The spec allows the *visible* top to move by up to a line, because the
    // new layout shows the line containing the anchor. What must not happen is
    // the anchor itself being re-rounded to each new layout's line start: that
    // would walk the stored position backwards a line per display change.
    final saves = <PositionSnapshot>[];
    final harness = await _reader(
      tester,
      Future.value(_progress()),
      saves: saves,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final restored = scroll.position.pixels;

    for (final size in [18.0, 22.0, 30.0, 14.0, 22.0, 14.0]) {
      harness.read(fontSizeProvider.notifier).previewFontSize(size);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(
        saves.last.offset,
        1000,
        reason: 'the anchor must survive a font size of $size unchanged',
      );
    }
    // Back at the original font the viewport lands exactly where it started.
    expect(scroll.position.pixels, closeTo(restored, 1));
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('horizontal restoration survives a narrower wrapped layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final content = List.filled(200, 'abcdefghij ').join();
    final container = ProviderContainer(
      overrides: [
        readingPositionWriterProvider.overrideWith((ref) {
          final writer = ReadingPositionWriter(save: (_) async {});
          ref.onDispose(writer.dispose);
          return writer;
        }),
        sharedPreferencesProvider.overrideWithValue(prefs),
        readingPositionForFileProvider.overrideWith(
          (ref, path) async => ReadingProgress(
            novelId: 'book',
            fileName: 'a.txt',
            updatedAt: DateTime(2026),
            bodyOffset: 1000,
            bodyHash: computeContentHash(content),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(selectedFileProvider.notifier)
        .selectFile(const FileEntry(name: 'a.txt', path: '/book/a.txt'));
    Future<void> pump(double width) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 250,
                  child: TextContentRenderer(content: content),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(400);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.pixels, greaterThan(100));
    final wideOffset = scroll.position.pixels;
    await pump(250);
    expect(scroll.position.pixels, greaterThan(wideOffset));
    await pump(400);
    expect(scroll.position.pixels, closeTo(wideOffset, 2));
    await tester.pump(const Duration(seconds: 2));
  });
}

final _content = List.filled(200, 'abcdefghij ').join();
ReadingProgress _progress({int offset = 1000}) => ReadingProgress(
  novelId: 'book',
  fileName: 'a.txt',
  updatedAt: DateTime(2026),
  bodyOffset: offset,
  bodyHash: computeContentHash(_content),
);

/// Restores [savedOffset], moves the viewport away and back to exactly the
/// restored pixel offset so a real capture runs there, and returns the body
/// offset that was persisted.
Future<int> _restoreThenCapture(WidgetTester tester, int savedOffset) async {
  final saves = <PositionSnapshot>[];
  final harness = await _reader(
    tester,
    Future.value(_progress(offset: savedOffset)),
    saves: saves,
  );
  await tester.pumpAndSettle();
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final restored = scroll.position.pixels;
  expect(restored, greaterThan(0));
  scroll.position.jumpTo(restored + 200);
  await tester.pumpAndSettle();
  scroll.position.jumpTo(restored);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const SizedBox());
  harness.dispose();
  return saves.last.offset;
}


Future<ProviderContainer> _reader(
  WidgetTester tester,
  Future<ReadingProgress?> progress, {
  bool fromStart = false,
  List<PositionSnapshot>? saves,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      readingPositionForFileProvider.overrideWith((ref, path) => progress),
      readingPositionWriterProvider.overrideWith((ref) {
        final writer = ReadingPositionWriter(
          save: (snapshot) async {
            saves?.add(snapshot);
          },
        );
        ref.onDispose(writer.dispose);
        return writer;
      }),
    ],
  );
  container
      .read(selectedFileProvider.notifier)
      .selectFile(const FileEntry(name: 'a.txt', path: '/book/a.txt'));
  if (fromStart) {
    container
        .read(pendingFileEntryIntentProvider.notifier)
        .set(FileEntryStartIntent.fromStart);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 250,
            child: TextContentRenderer(content: _content),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
