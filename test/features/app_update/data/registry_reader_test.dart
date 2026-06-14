import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/app_update/data/registry_reader.dart';

void main() {
  group('Win32RegistryReader', () {
    test('returns null on non-Windows without touching the registry', () {
      const reader = Win32RegistryReader();
      // On non-Windows this returns null before any registry access; on Windows
      // a clearly-nonexistent path returns null via the caught failure below.
      final value = reader.readString(
        r'Software\NovelViewer\__definitely_missing__',
        'InstallType',
      );
      expect(value, isNull);
    }, skip: Platform.isWindows ? 'Covered by the Windows-specific test' : null);

    test(
        'logs the read failure at FINE (expected fallback) and returns null '
        'for a missing key', () {
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(() {
        sub.cancel();
        Logger.root.level = previousLevel;
      });

      const reader = Win32RegistryReader();
      final value = reader.readString(
        r'Software\NovelViewer\__definitely_missing_subkey__',
        'InstallType',
      );

      expect(value, isNull);
      final emitted =
          records.where((r) => r.loggerName == 'app_update.registry');
      expect(emitted, isNotEmpty);
      // Missing key is the normal case for most users; must stay below the
      // release threshold (Level.INFO) so it never pollutes release logs.
      expect(emitted.every((r) => r.level < Level.INFO), isTrue);
    }, skip: !Platform.isWindows ? 'Registry access is Windows-only' : null);
  });
}
