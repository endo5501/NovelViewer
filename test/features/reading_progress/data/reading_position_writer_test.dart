import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_position_writer.dart';

void main() {
  test(
    'continuous observations save periodically and unchanged ones stay clean',
    () {
      fakeAsync((clock) {
        final saved = <int>[];
        final writer = ReadingPositionWriter(
          save: (snapshot) async {
            saved.add(snapshot.offset);
          },
        );
        for (var i = 1; i <= 6; i++) {
          writer.observe(PositionSnapshot('book', 'a', i, 'hash'));
          clock.elapse(const Duration(milliseconds: 500));
          clock.flushMicrotasks();
        }
        expect(saved, [4]);
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        expect(saved, [4, 6]);
        writer.observe(const PositionSnapshot('book', 'a', 6, 'hash'));
        clock.elapse(const Duration(seconds: 3));
        expect(saved, [4, 6]);
        writer.dispose();
      });
    },
  );

  test(
    'flush and other operations keep order despite delayed writes',
    () async {
      final gate = Completer<void>();
      final operations = <String>[];
      final writer = ReadingPositionWriter(
        save: (snapshot) async {
          if (snapshot.fileName == 'a') await gate.future;
          operations.add(snapshot.fileName);
        },
      );
      writer.observe(const PositionSnapshot('book', 'a', 2, 'hash'));
      final flush = writer.flush();
      final select = writer.enqueue(() async => operations.add('select b'));
      writer.observe(const PositionSnapshot('book', 'b', 3, 'hash'));
      final last = writer.flush();
      gate.complete();
      await Future.wait([flush, select, last]);
      expect(operations, ['a', 'select b', 'b']);
      writer.dispose();
    },
  );

  test(
    'a failed write is retried by the next flush of the same position',
    () async {
      // A transient DB lock must not lose the position outright: the reader may
      // be sitting still, so if the failed snapshot is neither re-armed nor
      // allowed past the dedupe guard, nothing is ever written again and the
      // exit flush finds an empty queue.
      var attempts = 0;
      final saved = <int>[];
      final writer = ReadingPositionWriter(
        save: (snapshot) async {
          attempts++;
          if (attempts == 1) throw StateError('locked');
          saved.add(snapshot.offset);
        },
      );
      writer.observe(const PositionSnapshot('book', 'a', 42, 'hash'));
      await writer.flush();
      expect(saved, isEmpty);
      // Same position observed again (the reader has not moved).
      writer.observe(const PositionSnapshot('book', 'a', 42, 'hash'));
      await writer.flush();
      expect(saved, [42]);
      writer.dispose();
    },
  );

  test(
    'failed writes do not break later saves and deletion discards dirty data',
    () async {
      final saved = <int>[];
      final writer = ReadingPositionWriter(
        save: (snapshot) async {
          if (snapshot.offset == 1) throw StateError('unavailable');
          saved.add(snapshot.offset);
        },
      );
      writer.observe(const PositionSnapshot('book', 'a', 1, 'hash'));
      await writer.flush();
      writer.observe(const PositionSnapshot('book', 'a', 2, 'hash'));
      await writer.flush();
      writer.observe(const PositionSnapshot('book', 'a', 3, 'hash'));
      await writer.forgetNovel('book');
      await writer.flush();
      expect(saved, [2]);
      writer.dispose();
    },
  );

  test('a pending position follows its file to a new name', () async {
    final saved = <PositionSnapshot>[];
    final writer = ReadingPositionWriter(save: (s) async => saved.add(s));
    writer.observe(const PositionSnapshot('book', '9_x.txt', 1500, 'hash'));

    writer.renamePending('book', {'9_x.txt': '09_x.txt'});
    await writer.flush();

    expect(saved, [const PositionSnapshot('book', '09_x.txt', 1500, 'hash')]);
    writer.dispose();
  });

  test(
    'renamePending leaves positions of other novels and files alone',
    () async {
      final saved = <PositionSnapshot>[];
      final writer = ReadingPositionWriter(save: (s) async => saved.add(s));
      writer.observe(const PositionSnapshot('other', '9_x.txt', 5, 'hash'));

      writer.renamePending('book', {'9_x.txt': '09_x.txt'});
      await writer.flush();

      expect(saved.single.fileName, '9_x.txt');
      writer.dispose();
    },
  );

  test(
    'a position already queued under the old name is saved under the new',
    () async {
      final saved = <PositionSnapshot>[];
      final writer = ReadingPositionWriter(save: (s) async => saved.add(s));
      final gate = Completer<void>();
      // Stands in for the rekey still running in the queue.
      final rekey = writer.enqueue(() => gate.future);
      writer.observe(const PositionSnapshot('book', '9_x.txt', 1500, 'hash'));
      final queued = writer.flush();

      writer.renamePending('book', {'9_x.txt': '09_x.txt'});
      gate.complete();
      await Future.wait([rekey, queued]);

      expect(saved, [const PositionSnapshot('book', '09_x.txt', 1500, 'hash')]);
      writer.dispose();
    },
  );

  test(
    'a rename stops applying once the queue it covered has drained',
    () async {
      final saved = <PositionSnapshot>[];
      final writer = ReadingPositionWriter(save: (s) async => saved.add(s));
      writer.renamePending('book', {'9_x.txt': '09_x.txt'});
      await writer.flush();

      // A later file that happens to reuse the old name is its own file.
      writer.observe(const PositionSnapshot('book', '9_x.txt', 7, 'hash'));
      await writer.flush();

      expect(saved.single.fileName, '9_x.txt');
      writer.dispose();
    },
  );
}
