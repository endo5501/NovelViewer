import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/episode_navigation/domain/episode_boundary_prompt.dart';

/// Counts notifications so the tests can assert that a state change was
/// published, not just that the getter changed.
class _Listener {
  int count = 0;
  void call() => count++;
}

void main() {
  group('two-step confirmation', () {
    test('first boundary input arms the prompt without navigating', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        final listener = _Listener();
        prompt.addListener(listener.call);

        final navigate = prompt.hitBoundary(
          EpisodeBoundaryDirection.next,
          hasAdjacent: true,
        );

        expect(navigate, isFalse);
        expect(prompt.pending, EpisodeBoundaryDirection.next);
        expect(listener.count, 1);

        prompt.dispose();
      });
    });

    test('second same-direction input after the cooldown confirms', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(milliseconds: 300));

        final navigate = prompt.hitBoundary(
          EpisodeBoundaryDirection.next,
          hasAdjacent: true,
        );

        expect(navigate, isTrue);
        prompt.dispose();
      });
    });

    test('the previous direction behaves symmetrically', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();

        expect(
          prompt.hitBoundary(
            EpisodeBoundaryDirection.previous,
            hasAdjacent: true,
          ),
          isFalse,
        );
        expect(prompt.pending, EpisodeBoundaryDirection.previous);

        clock.elapse(const Duration(milliseconds: 300));

        expect(
          prompt.hitBoundary(
            EpisodeBoundaryDirection.previous,
            hasAdjacent: true,
          ),
          isTrue,
        );
        prompt.dispose();
      });
    });
  });

  group('prompt timeout', () {
    test('the prompt clears itself after four seconds', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        final listener = _Listener();
        prompt.addListener(listener.call);
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        clock.elapse(const Duration(milliseconds: 3999));
        expect(prompt.pending, EpisodeBoundaryDirection.next);

        clock.elapse(const Duration(milliseconds: 1));

        expect(prompt.pending, isNull);
        expect(listener.count, 2, reason: 'armed once, cleared once');
        prompt.dispose();
      });
    });

    test('input after a timeout is treated as a first input again', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(seconds: 4));
        expect(prompt.pending, isNull);

        final navigate = prompt.hitBoundary(
          EpisodeBoundaryDirection.next,
          hasAdjacent: true,
        );

        expect(navigate, isFalse);
        expect(prompt.pending, EpisodeBoundaryDirection.next);
        prompt.dispose();
      });
    });
  });

  group('confirm cooldown', () {
    test('a burst of inputs inside the cooldown never confirms', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        final navigations = <bool>[];

        for (var i = 0; i < 5; i++) {
          navigations.add(
            prompt.hitBoundary(
              EpisodeBoundaryDirection.next,
              hasAdjacent: true,
            ),
          );
          clock.elapse(const Duration(milliseconds: 50));
        }

        expect(navigations, everyElement(isFalse));
        expect(prompt.pending, EpisodeBoundaryDirection.next);
        prompt.dispose();
      });
    });

    test('an ignored input restarts the cooldown', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        clock.elapse(const Duration(milliseconds: 200));
        expect(
          prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true),
          isFalse,
          reason: 'still inside the 300ms cooldown',
        );

        // 350ms after arming but only 150ms after the ignored input, so the
        // gesture has not gone quiet yet.
        clock.elapse(const Duration(milliseconds: 150));
        expect(
          prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true),
          isFalse,
        );
        prompt.dispose();
      });
    });

    test('inertial scrolling cannot confirm on its own', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();

        // One macOS trackpad flick: ~1s of momentum events at ~60Hz, long past
        // the 300ms window measured from the first of them.
        var confirmed = false;
        for (var t = 0; t <= 1000; t += 16) {
          confirmed |= prompt.hitBoundary(
            EpisodeBoundaryDirection.next,
            hasAdjacent: true,
          );
          clock.elapse(const Duration(milliseconds: 16));
        }

        expect(
          confirmed,
          isFalse,
          reason: 'A single flick must not cross a file boundary',
        );
        expect(prompt.pending, EpisodeBoundaryDirection.next);

        // The momentum dies down; a deliberate second flick confirms.
        clock.elapse(const Duration(milliseconds: 300));
        expect(
          prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true),
          isTrue,
        );
        prompt.dispose();
      });
    });

    test('an ignored input does not extend the prompt timeout', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        clock.elapse(const Duration(milliseconds: 100));
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        // 3999ms after arming — the timeout has not fired yet.
        clock.elapse(const Duration(milliseconds: 3899));
        expect(prompt.pending, EpisodeBoundaryDirection.next);

        // 4000ms after arming, not after the ignored input.
        clock.elapse(const Duration(milliseconds: 1));
        expect(prompt.pending, isNull);
        prompt.dispose();
      });
    });
  });

  group('direction switch', () {
    test('an opposite boundary input re-arms in the other direction', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(milliseconds: 300));

        final navigate = prompt.hitBoundary(
          EpisodeBoundaryDirection.previous,
          hasAdjacent: true,
        );

        expect(navigate, isFalse);
        expect(prompt.pending, EpisodeBoundaryDirection.previous);
        prompt.dispose();
      });
    });

    test('confirming right after a direction switch is suppressed', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(milliseconds: 300));
        prompt.hitBoundary(
          EpisodeBoundaryDirection.previous,
          hasAdjacent: true,
        );

        clock.elapse(const Duration(milliseconds: 200));
        expect(
          prompt.hitBoundary(
            EpisodeBoundaryDirection.previous,
            hasAdjacent: true,
          ),
          isFalse,
          reason: 'the switch restarted the confirm cooldown',
        );
        prompt.dispose();
      });
    });

    test('the switch restarts the prompt timeout', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(seconds: 3));
        prompt.hitBoundary(
          EpisodeBoundaryDirection.previous,
          hasAdjacent: true,
        );

        // 4s after arming "next" but only 1s after switching to "previous".
        clock.elapse(const Duration(seconds: 1));
        expect(prompt.pending, EpisodeBoundaryDirection.previous);

        clock.elapse(const Duration(seconds: 3));
        expect(prompt.pending, isNull);
        prompt.dispose();
      });
    });
  });

  group('no adjacent file', () {
    test('a boundary input without an adjacent file is a no-op', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        final listener = _Listener();
        prompt.addListener(listener.call);

        final navigate = prompt.hitBoundary(
          EpisodeBoundaryDirection.next,
          hasAdjacent: false,
        );

        expect(navigate, isFalse);
        expect(prompt.pending, isNull);
        expect(listener.count, 0);
        prompt.dispose();
      });
    });

    test('it leaves an armed prompt in the other direction untouched', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(milliseconds: 300));

        final navigate = prompt.hitBoundary(
          EpisodeBoundaryDirection.previous,
          hasAdjacent: false,
        );

        expect(navigate, isFalse);
        expect(prompt.pending, EpisodeBoundaryDirection.next);
        prompt.dispose();
      });
    });
  });

  group('reset and disposal', () {
    test('confirming leaves the prompt disarmed', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(milliseconds: 300));
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        expect(prompt.pending, isNull);
        prompt.dispose();
      });
    });

    test('confirming notifies that the hint went away', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(milliseconds: 300));

        final listener = _Listener();
        prompt.addListener(listener.call);
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        expect(
          listener.count,
          1,
          reason:
              'Every pending transition publishes, so a viewer that renders '
              'the hint can drop it without relying on the navigation to '
              'rebuild it',
        );
        prompt.dispose();
      });
    });

    test('the input right after a confirm arms again instead of moving', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(milliseconds: 300));
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        clock.elapse(const Duration(milliseconds: 300));
        final navigate = prompt.hitBoundary(
          EpisodeBoundaryDirection.next,
          hasAdjacent: true,
        );

        expect(navigate, isFalse);
        expect(prompt.pending, EpisodeBoundaryDirection.next);
        prompt.dispose();
      });
    });

    test('reset disarms the prompt and notifies', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        final listener = _Listener();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        prompt.addListener(listener.call);

        prompt.reset();

        expect(prompt.pending, isNull);
        expect(listener.count, 1);
        prompt.dispose();
      });
    });

    test('reset on an idle prompt does not notify', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        final listener = _Listener();
        prompt.addListener(listener.call);

        prompt.reset();

        expect(listener.count, 0);
        prompt.dispose();
      });
    });

    test('reset cancels the pending timeout', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        prompt.reset();

        final listener = _Listener();
        prompt.addListener(listener.call);
        clock.elapse(const Duration(seconds: 10));

        expect(listener.count, 0, reason: 'the timeout timer was cancelled');
        prompt.dispose();
      });
    });

    test('reset clears the confirm cooldown so re-arming is immediate', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        prompt.reset();

        expect(
          prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true),
          isFalse,
        );
        expect(prompt.pending, EpisodeBoundaryDirection.next);
        prompt.dispose();
      });
    });

    test('dispose releases the pending timers', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt();
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        prompt.dispose();

        // A live timeout timer would fire into a disposed ChangeNotifier and
        // throw; fakeAsync also reports timers still pending at the end.
        clock.elapse(const Duration(seconds: 10));
      });
    });

    test('custom durations are honoured', () {
      fakeAsync((clock) {
        final prompt = EpisodeBoundaryPrompt(
          promptTimeout: const Duration(seconds: 1),
          confirmCooldown: const Duration(milliseconds: 50),
        );
        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);

        clock.elapse(const Duration(milliseconds: 50));
        expect(
          prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true),
          isTrue,
        );

        prompt.hitBoundary(EpisodeBoundaryDirection.next, hasAdjacent: true);
        clock.elapse(const Duration(seconds: 1));
        expect(prompt.pending, isNull);
        prompt.dispose();
      });
    });
  });
}
