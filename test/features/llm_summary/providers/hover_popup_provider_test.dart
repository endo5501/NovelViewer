import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(state.activeEpisode, isNull);
    });

    test('visible() factory produces a visible state with default episode',
        () {
      const state = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(100, 200),
        hoverToken: _tokenA,
      );

      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(100, 200));
      expect(state.hoverToken, _tokenA);
      expect(state.activeEpisode, isNull,
          reason:
              'activeEpisode defaults to null, signalling "use default rule"');
    });

    test('visible() factory honors explicit activeEpisode', () {
      const state = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(100, 200),
        hoverToken: _tokenA,
        activeEpisode: 40,
      );

      expect(state.activeEpisode, 40);
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

    test('different activeEpisode values produce non-equal states', () {
      const a = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
        hoverToken: _tokenA,
        activeEpisode: 30,
      );
      const b = HoverPopupState.visible(
        word: 'アリス',
        position: Offset(10, 20),
        hoverToken: _tokenA,
        activeEpisode: 60,
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
      expect(state.activeEpisode, isNull,
          reason: 'show() leaves activeEpisode at null (default rule)');
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

    test('setActiveEpisode updates active snapshot while preserving identity',
        () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.setActiveEpisode(60);

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.word, 'アリス');
      expect(state.position, const Offset(50, 75));
      expect(state.hoverToken, _tokenA);
      expect(state.activeEpisode, 60);
    });

    test('setActiveEpisode(null) clears the override (re-apply default rule)',
        () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.setActiveEpisode(30);
      notifier.setActiveEpisode(null);

      expect(container.read(hoverPopupProvider).activeEpisode, isNull);
    });

    test('setActiveEpisode is a no-op when the popup is hidden', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.setActiveEpisode(30);

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isFalse);
    });

    test('show() with a different token resets activeEpisode to null', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.setActiveEpisode(60);
      notifier.show(
          word: 'ボブ', position: const Offset(100, 200), token: _tokenB);

      final state = container.read(hoverPopupProvider);
      expect(state.word, 'ボブ');
      expect(state.hoverToken, _tokenB);
      expect(state.activeEpisode, isNull,
          reason: 'New occurrence starts with the default snapshot rule');
    });

    test('show() with the same token is a no-op (position is NOT updated)',
        () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      notifier.show(
          word: 'アリス', position: const Offset(50, 75), token: _tokenA);
      notifier.show(
          word: 'アリス',
          position: const Offset(999, 999),
          token: _tokenA);

      final state = container.read(hoverPopupProvider);
      expect(state.position, const Offset(50, 75));
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
        expect(container.read(hoverPopupProvider).hoverToken, _tokenA);

        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 500));
        expect(container.read(hoverPopupProvider).isVisible, isFalse);
      });
    });

    test(
        'pointer moving between two occurrences of the SAME word switches '
        'the popup to the new occurrence', () {
      final container = makeContainer();
      final notifier = container.read(hoverPopupProvider.notifier);

      const tokenAlice1 = (start: 0, end: 3);
      const tokenAlice2 = (start: 20, end: 23);

      notifier.show(
          word: 'アリス', position: const Offset(10, 10), token: tokenAlice1);
      notifier.show(
          word: 'アリス', position: const Offset(30, 10), token: tokenAlice2);
      notifier.hideIfShowing(tokenAlice1);

      final state = container.read(hoverPopupProvider);
      expect(state.isVisible, isTrue);
      expect(state.hoverToken, tokenAlice2);
      expect(state.position, const Offset(30, 10));
    });
  });

  group('popup-hover grace period', () {
    test('hideIfShowing schedules a deferred hide', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.hideIfShowing(_tokenA);

        expect(container.read(hoverPopupProvider).isVisible, isTrue);

        async.elapse(const Duration(milliseconds: 200));

        expect(container.read(hoverPopupProvider).isVisible, isFalse);
      });
    });

    test('grace-period boundary: visible at 149 ms, hidden after 150 ms', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.hideIfShowing(_tokenA);

        async.elapse(const Duration(milliseconds: 149));
        expect(container.read(hoverPopupProvider).isVisible, isTrue);

        async.elapse(const Duration(milliseconds: 2));
        expect(container.read(hoverPopupProvider).isVisible, isFalse);
      });
    });

    test('onPopupEnter during the grace window cancels the deferred hide', () {
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

        expect(container.read(hoverPopupProvider).isVisible, isTrue);
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

        expect(container.read(hoverPopupProvider).isVisible, isFalse);
      });
    });

    test('programmatic hide() resets the popup-hover latch', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.onPopupEnter();
        notifier.hide();

        notifier.show(
            word: 'ボブ', position: const Offset(20, 20), token: _tokenB);
        notifier.hideIfShowing(_tokenB);
        async.elapse(const Duration(milliseconds: 300));

        expect(container.read(hoverPopupProvider).isVisible, isFalse);
      });
    });

    test('show() cancels any pending hide timer', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 50));
        notifier.show(
            word: 'ボブ', position: const Offset(20, 0), token: _tokenB);
        async.elapse(const Duration(milliseconds: 500));

        final state = container.read(hoverPopupProvider);
        expect(state.isVisible, isTrue);
        expect(state.word, 'ボブ');
      });
    });

    test('while the popup is hovered, a stale exit(token) is suppressed', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(hoverPopupProvider.notifier);

        notifier.show(
            word: 'アリス', position: const Offset(0, 0), token: _tokenA);
        notifier.onPopupEnter();
        notifier.hideIfShowing(_tokenA);
        async.elapse(const Duration(milliseconds: 500));

        expect(container.read(hoverPopupProvider).isVisible, isTrue);
      });
    });
  });

  group('hover transition A -> B (cross-event ordering)', () {
    test('[exit(A), enter(B)] in order leaves final state as B', () {
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

    test('[enter(B), exit(A)] in order leaves final state as B', () {
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
        expect(state.word, 'B');
        expect(state.position, const Offset(20, 20));
      });
    });
  });
}
