import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_cache_provider.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

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

Widget _wrap(Widget child, ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Widget _wrapWithBrightness(
  Widget child,
  ProviderContainer container,
  Brightness brightness,
) {
  final themeData = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Pin both slots to the same brightness-matching theme and use
      // themeMode explicitly so a future maintainer adding darkTheme: for
      // symmetry cannot silently route the dark test to the light theme
      // via the default themeMode: ThemeMode.system.
      theme: themeData,
      darkTheme: themeData,
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: child),
    ),
  );
}

const _aliceKey = (folder: 'novel_a', word: 'アリス');

void main() {
  group('HoverPopupWidget content', () {
    testWidgets('renders the no-spoiler summary when only no-spoiler is cached',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(type: SummaryType.noSpoiler, text: 'アリスは主人公。'),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: '040_chapter.txt',
        ),
        container,
      ));
      await tester.pumpAndSettle();

      expect(find.text('アリスは主人公。'), findsOneWidget);
    });

    testWidgets('renders the spoiler summary when only spoiler is cached',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            spoiler: _summary(
                type: SummaryType.spoiler, text: 'アリスは第三王女で剣術の達人。'),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: null,
        ),
        container,
      ));
      await tester.pumpAndSettle();

      expect(find.text('アリスは第三王女で剣術の達人。'), findsOneWidget);
    });

    testWidgets('hides the [なし|あり] toggle when only one type is cached',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(type: SummaryType.noSpoiler, text: 'なしのみ'),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: null,
        ),
        container,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_type_toggle')), findsNothing,
          reason:
              'Toggle pill must not appear when only one summary type exists');
    });

    testWidgets(
        'shows the [なし|あり] toggle and defaults to no-spoiler when both cached',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(type: SummaryType.noSpoiler, text: 'なし本文'),
            spoiler: _summary(type: SummaryType.spoiler, text: 'あり本文'),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      // The notifier must be visible for setSummaryType to be applicable later.
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(0, 0),
            token: const (start: 0, end: 3),
          );

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: null,
        ),
        container,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_type_toggle')), findsOneWidget);
      expect(find.text('なし本文'), findsOneWidget,
          reason: 'no-spoiler must be the initial active summary');
      expect(find.text('あり本文'), findsNothing);
    });

    testWidgets('tapping "あり" on the toggle switches the displayed summary',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(type: SummaryType.noSpoiler, text: 'なし本文'),
            spoiler: _summary(type: SummaryType.spoiler, text: 'あり本文'),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(0, 0),
            token: const (start: 0, end: 3),
          );

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: null,
        ),
        container,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('hover_popup_type_spoiler')));
      await tester.pumpAndSettle();

      expect(find.text('あり本文'), findsOneWidget);
      expect(find.text('なし本文'), findsNothing);
      expect(container.read(hoverPopupProvider).activeType,
          SummaryType.spoiler);
    });

    testWidgets('renders nothing when both summary rows are null',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => const WordSummariesByType(),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: null,
        ),
        container,
      ));
      await tester.pumpAndSettle();

      // Nothing meaningful rendered — no summary text, no toggle, no warning.
      expect(find.byKey(const Key('hover_popup_card')), findsNothing);
    });
  });

  group('HoverPopupWidget reference-position warning', () {
    testWidgets(
        'shows warning when no-spoiler sourceFile differs from currentFileName',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(
              type: SummaryType.noSpoiler,
              text: 'なし本文',
              sourceFile: '030_chapter.txt',
            ),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: '040_chapter.txt',
        ),
        container,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_reference_warning')),
          findsOneWidget);
    });

    testWidgets(
        'hides warning when no-spoiler sourceFile equals currentFileName',
        (tester) async {
      final container = ProviderContainer(overrides: [
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
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: '040_chapter.txt',
        ),
        container,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_reference_warning')),
          findsNothing);
    });

    testWidgets('hides warning when displaying the spoiler summary',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(
              type: SummaryType.noSpoiler,
              text: 'なし本文',
              sourceFile: '030_chapter.txt',
            ),
            spoiler: _summary(
                type: SummaryType.spoiler,
                text: 'あり本文',
                sourceFile: '030_chapter.txt'),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(0, 0),
            token: const (start: 0, end: 3),
          );

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: '040_chapter.txt',
        ),
        container,
      ));
      await tester.pumpAndSettle();

      // Switch to spoiler.
      await tester.tap(find.byKey(const Key('hover_popup_type_spoiler')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_reference_warning')),
          findsNothing,
          reason:
              'Warning must not appear while the spoiler view is active');
    });

    testWidgets(
        'hides warning when no-spoiler sourceFile is null (legacy entry)',
        (tester) async {
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey).overrideWith(
          (_) async => WordSummariesByType(
            noSpoiler: _summary(
              type: SummaryType.noSpoiler,
              text: 'なし本文',
              // sourceFile intentionally omitted
            ),
          ),
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: '040_chapter.txt',
        ),
        container,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_reference_warning')),
          findsNothing);
    });
  });

  group('HoverPopupWidget visual separation', () {
    void verifyCardSurface(WidgetTester tester) {
      final cardFinder = find.byKey(const Key('hover_popup_card'));
      expect(cardFinder, findsOneWidget);
      final material = tester.widget<Material>(cardFinder);
      final colorScheme =
          Theme.of(tester.element(cardFinder)).colorScheme;

      expect(material.color, colorScheme.surfaceContainerHighest,
          reason: 'Popup background must use surfaceContainerHighest token');

      // Elevation is the shadow half of the dual visual-separation cue
      // (shadow + border). Drop-shadow vanishing would silently regress
      // half the design even if the border survives.
      expect(material.elevation, 4.0,
          reason: 'Popup elevation must remain 4');

      expect(material.shape, isA<RoundedRectangleBorder>(),
          reason: 'Popup shape must be a RoundedRectangleBorder');
      final shape = material.shape! as RoundedRectangleBorder;

      expect(shape.side.color, colorScheme.outlineVariant,
          reason: 'Popup border must use outlineVariant token');
      expect(shape.side.width, 1.0,
          reason: 'Popup border width must be 1 px');
      // BorderStyle.none would keep color/width equal but render no line —
      // pin solid so that subtle regression cannot pass silently.
      expect(shape.side.style, BorderStyle.solid,
          reason: 'Popup border must be visibly drawn (solid style)');

      expect(shape.borderRadius, BorderRadius.circular(6),
          reason: 'Popup corner radius must remain 6 px');
    }

    testWidgets(
      '_Card uses surfaceContainerHighest + outlineVariant border in light theme',
      (tester) async {
        final container = ProviderContainer(overrides: [
          hoverPopupCacheProvider(_aliceKey).overrideWith(
            (_) async => WordSummariesByType(
              noSpoiler:
                  _summary(type: SummaryType.noSpoiler, text: 'ライト本文'),
            ),
          ),
        ]);
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrapWithBrightness(
          const HoverPopupWidget(
            folder: 'novel_a',
            word: 'アリス',
            currentFileName: null,
          ),
          container,
          Brightness.light,
        ));
        await tester.pumpAndSettle();

        verifyCardSurface(tester);
      },
    );

    testWidgets(
      '_Card uses surfaceContainerHighest + outlineVariant border in dark theme',
      (tester) async {
        final container = ProviderContainer(overrides: [
          hoverPopupCacheProvider(_aliceKey).overrideWith(
            (_) async => WordSummariesByType(
              noSpoiler:
                  _summary(type: SummaryType.noSpoiler, text: 'ダーク本文'),
            ),
          ),
        ]);
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrapWithBrightness(
          const HoverPopupWidget(
            folder: 'novel_a',
            word: 'アリス',
            currentFileName: null,
          ),
          container,
          Brightness.dark,
        ));
        await tester.pumpAndSettle();

        verifyCardSurface(tester);
      },
    );

    testWidgets(
      '_LoadingCard uses surfaceContainerHighest + outlineVariant border in light theme',
      (tester) async {
        final completer = Completer<WordSummariesByType>();
        final container = ProviderContainer(overrides: [
          hoverPopupCacheProvider(_aliceKey)
              .overrideWith((_) => completer.future),
        ]);
        addTearDown(container.dispose);
        addTearDown(() {
          if (!completer.isCompleted) {
            completer.complete(const WordSummariesByType());
          }
        });

        await tester.pumpWidget(_wrapWithBrightness(
          const HoverPopupWidget(
            folder: 'novel_a',
            word: 'アリス',
            currentFileName: null,
          ),
          container,
          Brightness.light,
        ));
        await tester.pump();

        expect(find.byKey(const Key('hover_popup_loading')), findsOneWidget,
            reason: 'Loading-state card must be the one rendered');
        verifyCardSurface(tester);
      },
    );

    testWidgets(
      '_LoadingCard uses surfaceContainerHighest + outlineVariant border in dark theme',
      (tester) async {
        final completer = Completer<WordSummariesByType>();
        final container = ProviderContainer(overrides: [
          hoverPopupCacheProvider(_aliceKey)
              .overrideWith((_) => completer.future),
        ]);
        addTearDown(container.dispose);
        addTearDown(() {
          if (!completer.isCompleted) {
            completer.complete(const WordSummariesByType());
          }
        });

        await tester.pumpWidget(_wrapWithBrightness(
          const HoverPopupWidget(
            folder: 'novel_a',
            word: 'アリス',
            currentFileName: null,
          ),
          container,
          Brightness.dark,
        ));
        await tester.pump();

        expect(find.byKey(const Key('hover_popup_loading')), findsOneWidget,
            reason: 'Loading-state card must be the one rendered');
        verifyCardSurface(tester);
      },
    );

    testWidgets(
      'type-toggle border uses outlineVariant token to align with card edge',
      (tester) async {
        final container = ProviderContainer(overrides: [
          hoverPopupCacheProvider(_aliceKey).overrideWith(
            (_) async => WordSummariesByType(
              noSpoiler: _summary(type: SummaryType.noSpoiler, text: 'なし'),
              spoiler: _summary(type: SummaryType.spoiler, text: 'あり'),
            ),
          ),
        ]);
        addTearDown(container.dispose);

        // The notifier must be visible so the toggle pill renders.
        container.read(hoverPopupProvider.notifier).show(
              word: 'アリス',
              position: const Offset(0, 0),
              token: const (start: 0, end: 3),
            );

        await tester.pumpWidget(_wrapWithBrightness(
          const HoverPopupWidget(
            folder: 'novel_a',
            word: 'アリス',
            currentFileName: null,
          ),
          container,
          Brightness.dark,
        ));
        await tester.pumpAndSettle();

        final toggleFinder = find.byKey(const Key('hover_popup_type_toggle'));
        expect(toggleFinder, findsOneWidget);
        final container_ = tester.widget<Container>(toggleFinder);
        final decoration = container_.decoration! as BoxDecoration;
        final border = decoration.border! as Border;
        final colorScheme =
            Theme.of(tester.element(toggleFinder)).colorScheme;

        // The pill-row border must share the outer card's outlineVariant
        // token so the two borders read as a single coherent panel rather
        // than nested concentric outlines with inverted strength
        // (dividerColor → outline is *stronger* than outlineVariant in M3).
        expect(border.top.color, colorScheme.outlineVariant,
            reason:
                'Toggle border must use outlineVariant to avoid stronger '
                'inner outline than the new card border');
      },
    );

    testWidgets(
      '_Card preserves overall size and child layout',
      (tester) async {
        final container = ProviderContainer(overrides: [
          hoverPopupCacheProvider(_aliceKey).overrideWith(
            (_) async => WordSummariesByType(
              noSpoiler: _summary(type: SummaryType.noSpoiler, text: '本文'),
            ),
          ),
        ]);
        addTearDown(container.dispose);

        await tester.pumpWidget(_wrapWithBrightness(
          const HoverPopupWidget(
            folder: 'novel_a',
            word: 'アリス',
            currentFileName: null,
          ),
          container,
          Brightness.light,
        ));
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(const Key('hover_popup_card'));

        // ConstrainedBox(maxWidth: 320) is the original popup width cap.
        final constrainedFinder = find.descendant(
          of: cardFinder,
          matching: find.byWidgetPredicate(
            (w) => w is ConstrainedBox && w.constraints.maxWidth == 320,
          ),
        );
        expect(constrainedFinder, findsOneWidget,
            reason:
                'Popup must keep its ConstrainedBox(maxWidth: 320) cap');

        // Inner content padding fromLTRB(12, 8, 12, 10) is the original
        // breathing room around the summary text + toggle pill.
        final paddingFinder = find.descendant(
          of: cardFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Padding &&
                w.padding == const EdgeInsets.fromLTRB(12, 8, 12, 10),
          ),
        );
        expect(paddingFinder, findsOneWidget,
            reason:
                'Popup must keep its original fromLTRB(12, 8, 12, 10) '
                'content padding');
      },
    );

    testWidgets(
      '_LoadingCard preserves overall size and child layout',
      (tester) async {
        final completer = Completer<WordSummariesByType>();
        final container = ProviderContainer(overrides: [
          hoverPopupCacheProvider(_aliceKey)
              .overrideWith((_) => completer.future),
        ]);
        addTearDown(container.dispose);
        addTearDown(() {
          if (!completer.isCompleted) {
            completer.complete(const WordSummariesByType());
          }
        });

        await tester.pumpWidget(_wrapWithBrightness(
          const HoverPopupWidget(
            folder: 'novel_a',
            word: 'アリス',
            currentFileName: null,
          ),
          container,
          Brightness.light,
        ));
        await tester.pump();

        final cardFinder = find.byKey(const Key('hover_popup_card'));

        final paddingFinder = find.descendant(
          of: cardFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding == const EdgeInsets.all(12),
          ),
        );
        expect(paddingFinder, findsOneWidget,
            reason:
                'Loading card must keep its original EdgeInsets.all(12) '
                'padding');

        final spinner = tester.widget<SizedBox>(
            find.byKey(const Key('hover_popup_loading')));
        expect(spinner.width, 24,
            reason: 'Loading spinner width must remain 24');
        expect(spinner.height, 24,
            reason: 'Loading spinner height must remain 24');
      },
    );
  });

  group('HoverPopupWidget loading state', () {
    testWidgets('shows loading indicator while the cache fetch is in flight',
        (tester) async {
      final completer = Completer<WordSummariesByType>();
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey)
            .overrideWith((_) => completer.future),
      ]);
      addTearDown(container.dispose);
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(const WordSummariesByType());
        }
      });

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: null,
        ),
        container,
      ));
      // Pump once — DO NOT pumpAndSettle (would await the future forever).
      await tester.pump();

      expect(find.byKey(const Key('hover_popup_loading')), findsOneWidget);
    });

    testWidgets(
        'replaces loading indicator with content once the future resolves',
        (tester) async {
      final completer = Completer<WordSummariesByType>();
      final container = ProviderContainer(overrides: [
        hoverPopupCacheProvider(_aliceKey)
            .overrideWith((_) => completer.future),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(
        const HoverPopupWidget(
          folder: 'novel_a',
          word: 'アリス',
          currentFileName: null,
        ),
        container,
      ));
      await tester.pump();

      expect(find.byKey(const Key('hover_popup_loading')), findsOneWidget);

      completer.complete(WordSummariesByType(
        noSpoiler: _summary(type: SummaryType.noSpoiler, text: '解決後本文'),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('hover_popup_loading')), findsNothing);
      expect(find.text('解決後本文'), findsOneWidget);
    });
  });
}
