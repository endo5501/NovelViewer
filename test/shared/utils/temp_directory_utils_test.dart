import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/utils/temp_directory_utils.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory testRoot;

  setUp(() async {
    testRoot = await Directory.systemTemp.createTemp('ensure_temp_dir_test_');
  });

  tearDown(() async {
    if (await testRoot.exists()) {
      await testRoot.delete(recursive: true);
    }
  });

  group('ensureTemporaryDirectory', () {
    test('creates the directory when it does not exist', () async {
      final missing = Directory(p.join(testRoot.path, 'sandbox_bundle_id'));
      expect(await missing.exists(), isFalse);

      final result = await ensureTemporaryDirectory(
        provider: () async => missing,
      );

      expect(await result.exists(), isTrue);
      expect(result.path, missing.path);
    });

    test('returns existing directory without error', () async {
      final existing = Directory(p.join(testRoot.path, 'already_there'));
      await existing.create();

      final result = await ensureTemporaryDirectory(
        provider: () async => existing,
      );

      expect(await result.exists(), isTrue);
      expect(result.path, existing.path);
    });

    test('creates intermediate parent directories', () async {
      final nested = Directory(p.join(testRoot.path, 'a', 'b', 'c'));

      final result = await ensureTemporaryDirectory(
        provider: () async => nested,
      );

      expect(await result.exists(), isTrue);
    });

    test('propagates exceptions from the provider', () async {
      await expectLater(
        ensureTemporaryDirectory(
          provider: () async => throw StateError('provider failed'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
