import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_summary_result.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';

const _tokenA = (start: 0, end: 3);
const _tokenB = (start: 5, end: 8);

void main() {
  group('HoverPopupState', () {
    test('hidden() factory produces an invisible state', () {
      const state = HoverPopupState.hidden();

      expect(state.isVisible, isFalse);
      expect(state.word, isNull);
      expect(state.position, isNull);
      expect(state.hoverToken, isNull);
      expect(state.activeType, SummaryType.noSpoiler,
          reason: 'activeType defaults to noSpoiler even when hidden');
    });

    test('visible() factory produces a visible state with given fields', () {
      const state = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(100, 200),
        hoverToken: _tokenA,
      );

      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(100, 200));
      expect(state.hoverToken, _tokenA);
      expect(state.activeType, SummaryType.noSpoiler,
          reason: 'activeType defaults to noSpoiler when not specified');
    });

    test('visible() factory honors explicit activeType', () {
      const state = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(100, 200),
        hoverToken: _tokenA,
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
        hoverToken: _tokenA,
      );
      const b = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
        hoverToken: _tokenA,
      );

      expect(a, equals(b));
    });

    test('different tokens produce non-equal states', () {
      const a = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
        hoverToken: _tokenA,
      );
      const b = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
        hoverToken: _tokenB,
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

    test(
        'show() makes the state visible with the given word, position, and token',
        () {
      final container = makeContainer();
      container.read(hoverPopupProvider.notifier).show(
            word: 'アリス',
            position: const Offset(50, 75),
            token: _tokenA,
          );

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(50, 75));
      expect(state.hoverToken, _tokenA);
      expect(state.activeType, SummaryType.noSpoiler,
          reason: 'show() resets activeType to the default noSpoiler');
    });

    test('hide() returns the state to hidden', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.hide();

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isFalse);
      expect(state.word, isNull);
    });

    test('setSummaryType updates activeType while preserving identity fields',
        () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.setSummaryType(SummaryType.spoiler);

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(50, 75));
      expect(state.hoverToken, _tokenA);
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

    test('show() with a different token replaces the request', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.setSummaryType(SummaryType.spoiler);
      notifier.show(
          word: 'ボブ', position: const Offset(100, 200), token: _tokenB);

      final state = container.read(hoverPopupProvider);
      expect(state.word, 'ボブ');
      expect(state.position, const Offset(100, 200));
      expect(state.hoverToken, _tokenB);
      expect(state.activeType, SummaryType.noSpoiler,
          reason:
              'A new show() resets activeType so the new occurrence starts with noSpoiler');
    });

    test('show() with the same token is a no-op (position is NOT updated)', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.show(
          word: 'アリス',
          position: const Offset(999, 999),
          token: _tokenA);

      final state = container.read(hoverPopupProvider);
      expect(state.position, const Offset(50, 75),
          reason:
              'Re-entering the SAME marked occurrence (e.g. sub-pixel pointer wobble) must not churn position');
    });

    test('hideIfShowing hides only when the same token is active', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.hideIfShowing(_tokenB);
        async.elapse(const Duration(milliseconds: 500));
        expect(container.read(hoverPopupProvider).hoverToken, _tokenA,
            reason: 'hideIfShowing(B) must not hide an active A popup');

        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 500));
        expect(container.read(hoverPopupProvider).isVisible, isFalse,
            reason: 'hideIfShowing must hide when tokens match');
      });
    });

    test(
        'pointer moving between two occurrences of the SAME word switches '
        'the popup to the new occurrence (not closed by the prior exit)', () {
      // Regression: previously hideIfShowing matched on word, so leaving the
      // first occurrence of "アリス" would also close the popup that just
      // opened on the second occurrence.
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      // Two occurrences of the same word at different positions.
      const tokenAlice1 = (start: 0, end: 3);
      const tokenAlice2 = (start: 20, end: 23);

      notifier.show(
          word: 'アリス', position: const Offset(10, 10), token: tokenAlice1);
      // Pointer moves to second occurrence; framework typically fires
      // exit(first) then enter(second), in either order.
      notifier.show(
          word: 'アリス', position: const Offset(30, 10), token: tokenAlice2);
      notifier.hideIfShowing(tokenAlice1);

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue,
          reason:
              'Popup must remain visible for the second occurrence after the '
              'exit handler for the first occurrence fires');
      expect(state.hoverToken, tokenAlice2);
      expect(state.position, const Offset(30, 10),
          reason: 'Popup position must reflect the new occurrence');
    });
  });

  group('popup-hover grace period', () {
    test(
        'hideIfShowing schedules a deferred hide that fires after the grace '
        'period when the popup was never entered', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.hideIfShowing(_tokenA);

        // Still visible immediately after the exit handler fires.
        expect(container.read(hoverPopupProvider).isVisible, isTrue,
            reason:
                'Hide must be deferred so the pointer can travel from the '
                'marked span to the popup widget');

        async.elapse(const Duration(milliseconds: 200));

        expect(container.read(hoverPopupProvider).isVisible, isFalse,
            reason: 'After the grace period elapses, the popup hides');
      });
    });

    test(
        'onPopupEnter during the grace window cancels the deferred hide so '
        'the popup stays visible while the pointer is inside it', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 80));
        notifier.onPopupEnter();
        async.elapse(const Duration(milliseconds: 500));

        expect(container.read(hoverPopupProvider).isVisible, isTrue,
            reason:
                'A timely onPopupEnter must cancel the scheduled hide so the '
                'user can interact with the popup');
      });
    });

    test('onPopupExit hides the popup immediately', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.onPopupEnter();
        async.flushMicrotasks();
        notifier.onPopupExit();

        expect(container.read(hoverPopupProvider).isVisible, isFalse,
            reason:
                'Leaving the popup itself bypasses the grace period — the '
                'user has clearly moved on');
      });
    });

    test(
        'programmatic hide() resets the popup-hover latch so a later '
        'hideIfShowing on a fresh popup is NOT suppressed',
        () {
      // Regression: when hide() was called while _popupHovered was true
      // (e.g. mode flip or page jump while pointer is inside the popup),
      // the latch lingered. The next popup's deferred hide then short-
      // circuited inside the grace-period callback and the new popup
      // stayed visible indefinitely.
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.onPopupEnter();
        // Mode switch / page jump path fires hide() while the pointer
        // happens to be over the popup.
        notifier.hide();

        // Fresh popup for a different mark.
        notifier.show(
            word: 'ボブ', position: const Offset(20, 20), token: _tokenB);
        // Pointer leaves the new mark and is NOT inside any popup.
        notifier.hideIfShowing(_tokenB);
        async.elapse(const Duration(milliseconds: 300));

        expect(container.read(hoverPopupProvider).isVisible, isFalse,
            reason:
                'After a programmatic hide(), the next popup must close '
                'normally via the grace-period exit timer.');
      });
    });

    test(
        'show() cancels any pending hide timer so re-entering a marked span '
        'immediately keeps the popup visible', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 50));
        // Pointer re-enters a marked span before the grace period elapses.
        notifier.show(
            word: 'ボブ', position: const Offset(20, 0), token: _tokenB);
        async.elapse(const Duration(milliseconds: 500));

        final state = container.read(hoverPopupProvider);
        expect(state.isVisible, isTrue);
        expect(state.word, 'ボブ');
      });
    });

    test(
        'while the popup is hovered, a stale exit(token) does NOT close it '
        'even after the grace period', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.onPopupEnter();
        // Pointer is inside the popup; a stray exit handler arrives.
        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 500));

        expect(container.read(hoverPopupProvider).isVisible, isTrue);
      });
    });
  });

  group('hover transition A -> B (cross-event ordering)', () {
    test(
        'when framework emits [exit(A), enter(B)] in order, final state is B',
        () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'A', position: const Offset(10, 10), token: _tokenA);

        notifier.hideIfShowing(_tokenA);
        notifier.show(
            word: 'B', position: const Offset(20, 20), token: _tokenB);
        async.elapse(const Duration(milliseconds: 500));

        final state = container.read(hoverPopupProvider);
        expect(state.word, 'B');
        expect(state.position, const Offset(20, 20));
      });
    });

    test(
        'when framework emits [enter(B), exit(A)] in order, final state is still B',
        () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'A', position: const Offset(10, 10), token: _tokenA);

        notifier.show(
            word: 'B', position: const Offset(20, 20), token: _tokenB);
        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 500));

        final state = container.read(hoverPopupProvider);
        expect(state.word, 'B',
            reason:
                'Out-of-order exit(A) after enter(B) must NOT hide the popup');
        expect(state.position, const Offset(20, 20));
      });
    });
  });
}
