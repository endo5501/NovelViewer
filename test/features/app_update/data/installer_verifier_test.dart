import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/data/installer_verifier.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  const verifier = InstallerVerifier();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('verifier_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<({String exePath, String sha256Path})> writeFiles({
    required List<int> exeBytes,
    required String sha256Content,
  }) async {
    final exePath = p.join(tempDir.path, 'setup.exe');
    final sha256Path = p.join(tempDir.path, 'setup.exe.sha256');
    await File(exePath).writeAsBytes(exeBytes);
    await File(sha256Path).writeAsString(sha256Content);
    return (exePath: exePath, sha256Path: sha256Path);
  }

  test('returns true when the computed hash matches the sidecar', () async {
    final bytes = [1, 2, 3, 4, 5];
    final hash = sha256.convert(bytes).toString();
    final files = await writeFiles(
      exeBytes: bytes,
      sha256Content: '$hash  setup.exe\n',
    );

    expect(
      await verifier.verify(
        exePath: files.exePath,
        sha256Path: files.sha256Path,
      ),
      isTrue,
    );
  });

  test('matches case-insensitively (uppercase sidecar hash)', () async {
    final bytes = [9, 8, 7];
    final hash = sha256.convert(bytes).toString().toUpperCase();
    final files = await writeFiles(
      exeBytes: bytes,
      sha256Content: '$hash  setup.exe\n',
    );

    expect(
      await verifier.verify(
        exePath: files.exePath,
        sha256Path: files.sha256Path,
      ),
      isTrue,
    );
  });

  test('returns false when the hash does not match', () async {
    final files = await writeFiles(
      exeBytes: [1, 2, 3],
      sha256Content:
          '${'0' * 64}  setup.exe\n',
    );

    expect(
      await verifier.verify(
        exePath: files.exePath,
        sha256Path: files.sha256Path,
      ),
      isFalse,
    );
  });

  test('returns false when the sidecar is malformed', () async {
    final files = await writeFiles(
      exeBytes: [1, 2, 3],
      sha256Content: 'not-a-hash\n',
    );

    expect(
      await verifier.verify(
        exePath: files.exePath,
        sha256Path: files.sha256Path,
      ),
      isFalse,
    );
  });

  test('returns false (not throws) when a file is missing', () async {
    expect(
      await verifier.verify(
        exePath: p.join(tempDir.path, 'nope.exe'),
        sha256Path: p.join(tempDir.path, 'nope.exe.sha256'),
      ),
      isFalse,
    );
  });
}
