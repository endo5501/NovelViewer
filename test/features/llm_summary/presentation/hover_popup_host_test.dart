import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_anchor.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_host.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

class _MockDisplayMode extends DisplayModeNotifier {
  _MockDisplayMode(this._initial);
  final TextDisplayMode _initial;

  @override
  TextDisplayMode build() => _initial;

  void set(TextDisplayMode mode) => state = mode;
}

class _MockSelectedFile extends SelectedFileNotifier {
  _MockSelectedFile(this._initial);
  final FileEntry? _initial;

  @override
  FileEntry? build() => _initial;
}

WordSummary _summary({
  required SummaryType type,
  required String text,
  String? sourceFile,
}) {
  final now = DateTime.parse('2026-05-24T10:00:00Z');
  return WordSummary(
    folderName: 'novel_a',
    word: 'アリス',
    summaryType: type,
    summary: text,
    sourceFile: sourceFile,
    createdAt: now,
    updatedAt: now,
  );
}

const _aliceKey = (folder: 'novel_a', word: 'アリス');

ProviderContainer _makeContainer({
  TextDisplayMode mode = TextDisplayMode.horizontal,
  String directory = '/library/novel_a',
  FileEntry? selectedFile,
}) {
  final container = ProviderContainer(overrides: [
    displayModeProvider.overrideWith(() => _MockDisplayMode(mode)),
    currentDirectoryProvider
        .overrideWith(() => CurrentDirectoryNotifier(directory)),
    selectedFileProvider.overrideWith(() => _MockSelectedFile(selectedFile)),
    hoverPopupCacheProvider(_aliceKey).overrideWith(
      (_) async => WordSummariesByType(
        noSpoiler: _summary(type: SummaryType.noSpoiler, text: 'なし本文'),
      ),
    ),
  ]);
  return container;
}

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('HoverPopupHost', () {
    testWidgets('initially shows no popup', (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets(
        'inserts popup into the overlay when state becomes visible in horizontal mode',
        (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      await tester.pumpAndSettle();

      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 100),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsOneWidget);
      expect(find.text('なし本文'), findsOneWidget);
    });

    testWidgets('removes popup from the overlay when state becomes hidden',
        (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 100),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsOneWidget);

      container.read(hoverPopupProvider.notifier).hide();
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets(
        'inserts popup in vertical mode when state becomes visible (the '
        'horizontal-only restriction has been lifted)',
        (tester) async {
      final container = _makeContainer(mode: TextDisplayMode.vertical);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 600),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsOneWidget,
          reason: 'Hover popup must appear in vertical mode too');
      expect(find.text('なし本文'), findsOneWidget);
    });

    testWidgets(
        'auto-hides popup and clears state when display mode flips '
        'horizontal → vertical',
        (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 100),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsOneWidget);

      (container.read(displayModeProvider.notifier) as _MockDisplayMode)
          .set(TextDisplayMode.vertical);
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });

    testWidgets(
        'auto-hides popup and clears state when display mode flips '
        'vertical → horizontal (mode-switch hide is unconditional)',
        (tester) async {
      final container = _makeContainer(mode: TextDisplayMode.vertical);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 600),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsOneWidget);

      (container.read(displayModeProvider.notifier) as _MockDisplayMode)
          .set(TextDisplayMode.horizontal);
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
      expect(container.read(hoverPopupProvider).isVisible, isFalse);
    });

    testWidgets(
      'horizontal mode positions popup at pointer + 16/+16 (top-left anchor)',
      (tester) async {
        final container = _makeContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrap(
          container,
          const HoverPopupHost(child: SizedBox.expand()),
        ));
        const pointer = Offset(200, 200);
        container.read(hoverPopupProvider.notifier).show(
              word: 'アリス',
              position: pointer,
              token: const (start: 0, end: 3),
            );
        await tester.pumpAndSettle();

        final positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byType(HoverPopupWidget),
            matching: find.byType(Positioned),
          ),
        );
        expect(positioned.left, pointer.dx + kHoverPopupGap);
        expect(positioned.top, pointer.dy + kHoverPopupGap);
      },
    );

    testWidgets(
      'vertical mode places popup up-right of pointer when room permits',
      (tester) async {
        final container = _makeContainer(mode: TextDisplayMode.vertical);
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrap(
          container,
          const HoverPopupHost(child: SizedBox.expand()),
        ));
        const pointer = Offset(200, 600); // far from edges
        container.read(hoverPopupProvider.notifier).show(
              word: 'アリス',
              position: pointer,
              token: const (start: 0, end: 3),
            );
        await tester.pumpAndSettle();

        final positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byType(HoverPopupWidget),
            matching: find.byType(Positioned),
          ),
        );
        expect(positioned.left, pointer.dx + kHoverPopupGap);
        expect(positioned.top,
            pointer.dy - kHoverPopupGap - kHoverPopupApproxHeight);
      },
    );

    testWidgets('does NOT insert popup when no novel directory is open',
        (tester) async {
      final container = ProviderContainer(overrides: [
        displayModeProvider
            .overrideWith(() => _MockDisplayMode(TextDisplayMode.horizontal)),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier(null)),
        selectedFileProvider.overrideWith(() => _MockSelectedFile(null)),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 100),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsNothing);
    });

    testWidgets('passes the currently selected file name to HoverPopupWidget',
        (tester) async {
      final container = _makeContainer(
        selectedFile: const FileEntry(
          name: '040_chapter.txt',
          path: '/library/novel_a/040_chapter.txt',
        ),
      );
      addTearDown(container.dispose);

      // Override the cache to include a no-spoiler summary whose sourceFile
      // matches the selected file — no warning should appear.
      final container2 = ProviderContainer(overrides: [
        displayModeProvider
            .overrideWith(() => _MockDisplayMode(TextDisplayMode.horizontal)),
        currentDirectoryProvider
            .overrideWith(() => CurrentDirectoryNotifier('/library/novel_a')),
        selectedFileProvider.overrideWith(() => _MockSelectedFile(
              const FileEntry(
                name: '040_chapter.txt',
                path: '/library/novel_a/040_chapter.txt',
              ),
            )),
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(
              type: SummaryType.noSpoiler,
              text: 'なし本文',
              sourceFile: '040_chapter.txt',
            ),
          ),
        ),
      ]);
      container.dispose();
      addTearDown(container2.dispose);

      await tester.pumpWidget(_wrap(
        container2,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      container2.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 100),
            token: const (start: 0, end: 3),
          );
      await tester.pumpAndSettle();

      expect(find.byType(HoverPopupWidget), findsOneWidget);
      expect(find.byKey(const Key('hover_popup_reference_warning')),
          findsNothing,
          reason:
              'Warning should be absent when sourceFile matches the selected file');
    });

    testWidgets(
        'pointer entering the popup widget cancels the deferred hide so the '
        '[なし|あり] toggle is reachable; leaving the popup hides it',
        (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        container,
        const HoverPopupHost(child: SizedBox.expand()),
      ));
      const token = (start: 0, end: 3);
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(100, 100),
            token: token,
          );
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsOneWidget);

      // Drive a real mouse pointer onto the popup card so the MouseRegion's
      // onEnter fires (this is what wires the widget to the notifier's
      // onPopupEnter — the gap manual verification of task 13.6 caught).
      final popupCenter =
          tester.getCenter(find.byKey(const Key('hover_popup_card')));
      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(-100, -100));
      addTearDown(gesture.removePointer);
      await gesture.moveTo(popupCenter);
      await tester.pump();

      // Simulate the marked-span exit handler firing as the pointer left
      // the word region. Without the popup-hover wiring this would close
      // the popup after the grace period.
      container.read(hoverPopupProvider.notifier).hideIfShowing(token);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HoverPopupWidget), findsOneWidget,
          reason:
              'Popup must stay visible while the pointer is inside it so the '
              'toggle pill can be clicked');

      // Now move the pointer off the popup — it must close immediately,
      // bypassing the grace period.
      await gesture.moveTo(const Offset(-100, -100));
      await tester.pumpAndSettle();
      expect(find.byType(HoverPopupWidget), findsNothing,
          reason:
              'Leaving the popup must hide it immediately (no grace period)');
    });
  });
}
