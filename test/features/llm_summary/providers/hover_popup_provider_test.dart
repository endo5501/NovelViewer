import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';

void main() {
  group('HoverPopupState', () {
    test('hidden() factory produces an invisible state', () {
      const state = HoverPopupState.hidden();

      expect(state.isVisible, isFalse);
      expect(state.word, isNull);
      expect(state.position, isNull);
      expect(state.activeType, SummaryType.noSpoiler,
          reason: 'activeType defaults to noSpoiler even when hidden');
    });

    test('visible() factory produces a visible state with given fields', () {
      const state = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(100, 200),
      );

      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(100, 200));
      expect(state.activeType, SummaryType.noSpoiler,
          reason: 'activeType defaults to noSpoiler when not specified');
    });

    test('visible() factory honors explicit activeType', () {
      const state = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(100, 200),
        activeType: SummaryType.spoiler,
      );

      expect(state.activeType, SummaryType.spoiler);
    });

    test('equal hidden states compare equal', () {
      expect(const HoverPopupState.hidden(),
          equals(const HoverPopupState.hidden()));
    });

    test('equal visible states compare equal', () {
      const a = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
      );
      const b = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
      );

      expect(a, equals(b));
    });

    test('different words produce non-equal states', () {
      const a = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
      );
      const b = HoverPopupState.visible(
        word: 'ボブ',
        position: Offset(10, 20),
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('HoverPopupNotifier', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('initial state is hidden', () {
      final container = makeContainer();
      final state = container.read(hoverPopupProvider);

      expect(state.isVisible, isFalse);
    });

    test('show() makes the state visible with the given word and position', () {
      final container = makeContainer();
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(50, 75),
          );

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(50, 75));
      expect(state.activeType, SummaryType.noSpoiler,
          reason: 'show() resets activeType to the default noSpoiler');
    });

    test('hide() returns the state to hidden', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(word: 'アリス', position: const Offset(50, 75));
      notifier.hide();

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isFalse);
      expect(state.word, isNull);
    });

    test('setSummaryType updates activeType while preserving word/position',
        () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(word: 'アリス', position: const Offset(50, 75));
      notifier.setSummaryType(SummaryType.spoiler);

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(50, 75));
      expect(state.activeType, SummaryType.spoiler);
    });

    test('setSummaryType is a no-op when the popup is hidden', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.setSummaryType(SummaryType.spoiler);

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isFalse,
          reason: 'setSummaryType on a hidden popup must not make it visible');
    });

    test('show() after show() with a different word replaces the request', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(word: 'アリス', position: const Offset(50, 75));
      notifier.setSummaryType(SummaryType.spoiler);
      notifier.show(word: 'ボブ', position: const Offset(100, 200));

      final state = container.read(hoverPopupProvider);
      expect(state.word, 'ボブ');
      expect(state.position, const Offset(100, 200));
      expect(state.activeType, SummaryType.noSpoiler,
          reason:
              'A new show() resets activeType so the new word starts with noSpoiler');
    });

    test('hideIfShowing hides only when currently showing the named word', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(word: 'アリス', position: const Offset(0, 0));
      notifier.hideIfShowing('ボブ');
      expect(container.read(hoverPopupProvider).word, 'アリス',
          reason: 'hideIfShowing("ボブ") must not hide an active "アリス" popup');

      notifier.hideIfShowing('アリス');
      expect(container.read(hoverPopupProvider).isVisible, isFalse,
          reason: 'hideIfShowing must hide when names match');
    });
  });

  group('hover transition A -> B (cross-event ordering)', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test(
        'when framework emits [exit(A), enter(B)] in order, final state is B',
        () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      // Initial: A is being shown.
      notifier.show(word: 'A', position: const Offset(10, 10));

      // Framework: leaving A, entering B.
      notifier.hideIfShowing('A');
      notifier.show(word: 'B', position: const Offset(20, 20));

      final state = container.read(hoverPopupProvider);
      expect(state.word, 'B');
      expect(state.position, const Offset(20, 20));
    });

    test(
        'when framework emits [enter(B), exit(A)] in order, final state is still B',
        () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      // Initial: A is being shown.
      notifier.show(word: 'A', position: const Offset(10, 10));

      // Framework: entering B FIRST, then leaving A. The exit handler must
      // not clobber B because we're no longer showing A.
      notifier.show(word: 'B', position: const Offset(20, 20));
      notifier.hideIfShowing('A');

      final state = container.read(hoverPopupProvider);
      expect(state.word, 'B',
          reason:
              'Out-of-order exit(A) after enter(B) must NOT hide the popup');
      expect(state.position, const Offset(20, 20));
    });
  });
}
