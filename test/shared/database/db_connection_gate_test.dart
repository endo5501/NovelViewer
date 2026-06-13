import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/database/database_closing_exception.dart';
import 'package:novel_viewer/shared/database/db_connection_gate.dart';

/// Minimal stand-in for an opened resource (e.g. a `Database`) whose `close()`
/// is observable, so the gate's interlock can be tested without a real SQLite
/// connection.
class _FakeResource {
  bool closed = false;
}

void main() {
  group('DbConnectionGate', () {
    test('concurrent access shares a single opener call (no double open)',
        () async {
      var openCount = 0;
      final opener = Completer<_FakeResource>();
      final gate = DbConnectionGate<_FakeResource>(
        opener: () {
          openCount++;
          return opener.future;
        },
        closer: (r) async {},
      );

      // Two accesses while the open is still in flight.
      final f1 = gate.resource;
      final f2 = gate.resource;
      final res = _FakeResource();
      opener.complete(res);

      expect(await f1, same(res));
      expect(await f2, same(res));
      expect(openCount, 1, reason: 'opener must run exactly once');
    });

    test('close awaits the in-flight open then closes that same resource',
        () async {
      final opener = Completer<_FakeResource>();
      final res = _FakeResource();
      var openCount = 0;
      final gate = DbConnectionGate<_FakeResource>(
        opener: () {
          openCount++;
          // First open is gated by the completer (to create the in-flight
          // race); any reopen yields a distinct fresh resource.
          return openCount == 1 ? opener.future : Future.value(_FakeResource());
        },
        closer: (r) async => r.closed = true,
      );

      final accessing = gate.resource; // open in flight
      final closing = gate.close(); // close starts while opening
      opener.complete(res);
      await accessing;
      await closing;

      expect(res.closed, isTrue,
          reason: 'close must wait for the open and close that handle');

      // Nothing retained: a subsequent access opens a fresh resource.
      final reopened = await gate.resource;
      expect(reopened, isNot(same(res)));
      expect(openCount, 2);
    });

    test('access during close throws DatabaseClosingException', () async {
      final opener = Completer<_FakeResource>();
      final gate = DbConnectionGate<_FakeResource>(
        opener: () => opener.future,
        closer: (r) async => Future<void>.delayed(Duration.zero),
      );

      gate.resource; // start the open so close has something to await
      final closing = gate.close(); // sets closing synchronously, awaits open

      expect(() => gate.resource, throwsA(isA<DatabaseClosingException>()));

      opener.complete(_FakeResource());
      await closing;
    });

    test('failed open is not cached and retries on next access', () async {
      var attempt = 0;
      final gate = DbConnectionGate<_FakeResource>(
        opener: () async {
          attempt++;
          if (attempt == 1) throw StateError('boom');
          return _FakeResource();
        },
        closer: (r) async {},
      );

      await expectLater(gate.resource, throwsStateError);
      final res = await gate.resource; // retry succeeds
      expect(res, isA<_FakeResource>());
      expect(attempt, 2, reason: 'failed open must not be cached');
    });

    test('reopens after close completes', () async {
      var openCount = 0;
      final gate = DbConnectionGate<_FakeResource>(
        opener: () async {
          openCount++;
          return _FakeResource();
        },
        closer: (r) async {},
      );

      await gate.resource; // open #1
      await gate.close();
      await gate.resource; // open #2, fresh

      expect(openCount, 2);
    });
  });
}
