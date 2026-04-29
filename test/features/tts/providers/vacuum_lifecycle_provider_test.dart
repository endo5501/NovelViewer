import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/providers/vacuum_lifecycle_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VacuumLifecycle', () {
    test('markDirty(folder) adds the folder to the pending set', () {
      final vacuumed = <String>[];
      final lifecycle = VacuumLifecycle(
        vacuumFolder: (folder) async => vacuumed.add(folder),
      );

      lifecycle.markDirty('/path/A');
      lifecycle.markDirty('/path/B');

      expect(lifecycle.pendingFolders, containsAll(['/path/A', '/path/B']));
      expect(vacuumed, isEmpty,
          reason: 'markDirty must NOT trigger vacuum synchronously');
    });

    test('detached lifecycle vacuums every pending folder', () async {
      final vacuumed = <String>[];
      final lifecycle = VacuumLifecycle(
        vacuumFolder: (folder) async => vacuumed.add(folder),
      );

      lifecycle.markDirty('/path/A');
      lifecycle.markDirty('/path/B');
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.detached);
      // Allow microtasks to drain.
      await Future<void>.delayed(Duration.zero);
      // Wait for in-flight vacuum to finish.
      await lifecycle.flushPending();

      expect(vacuumed, containsAll(['/path/A', '/path/B']));
      expect(lifecycle.pendingFolders, isEmpty);
    });

    test('non-detached lifecycle states do not vacuum', () async {
      final vacuumed = <String>[];
      final lifecycle = VacuumLifecycle(
        vacuumFolder: (folder) async => vacuumed.add(folder),
      );

      lifecycle.markDirty('/path/A');
      lifecycle
        ..didChangeAppLifecycleState(AppLifecycleState.resumed)
        ..didChangeAppLifecycleState(AppLifecycleState.inactive)
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);

      expect(vacuumed, isEmpty);
      expect(lifecycle.pendingFolders, contains('/path/A'));
    });

    test('markDirty() for the same folder vacuums only once', () async {
      var vacuumCount = 0;
      final lifecycle = VacuumLifecycle(
        vacuumFolder: (folder) async => vacuumCount++,
      );

      lifecycle
        ..markDirty('/path/A')
        ..markDirty('/path/A')
        ..markDirty('/path/A');
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.detached);
      await lifecycle.flushPending();

      expect(vacuumCount, 1);
    });

    test('vacuum errors do not block other folders', () async {
      final vacuumed = <String>[];
      final lifecycle = VacuumLifecycle(
        vacuumFolder: (folder) async {
          if (folder == '/path/B') throw Exception('boom');
          vacuumed.add(folder);
        },
      );

      lifecycle
        ..markDirty('/path/A')
        ..markDirty('/path/B')
        ..markDirty('/path/C');
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.detached);
      await lifecycle.flushPending();

      expect(vacuumed, containsAll(['/path/A', '/path/C']));
    });
  });
}
