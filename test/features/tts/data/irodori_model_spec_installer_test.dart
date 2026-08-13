import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_spec_installer.dart';
import 'package:path/path.dart' as p;

/// Writes the engine's model contract beside the downloaded model.
///
/// The shim resolves `<model_dir>/irodori_tts.json` as a spec override, which
/// outranks the contract embedded in the GGUF. Without it the engine rejects
/// `duration_correction` as an unknown option and captioned synthesis fails.
///
/// On Windows the build script also drops a copy next to the DLL, but on macOS
/// it cannot: the Frameworks directory is sealed by codesign, so a file there
/// breaks the signature. Writing beside the model works on both.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('irodori_spec_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  IrodoriModelSpecInstaller installer(String contents, {int? counter}) =>
      IrodoriModelSpecInstaller(loadSpec: () async => contents);

  test('writes the spec into the model directory', () async {
    await installer('{"family":"irodori_tts"}').install(tempDir.path);

    final written = File(p.join(tempDir.path, 'irodori_tts.json'));
    expect(written.existsSync(), isTrue);
    expect(written.readAsStringSync(), '{"family":"irodori_tts"}');
  });

  test('overwrites a stale spec left by an older build', () async {
    final existing = File(p.join(tempDir.path, 'irodori_tts.json'))
      ..writeAsStringSync('{"family":"irodori_tts","old":true}');

    await installer('{"family":"irodori_tts","new":true}').install(tempDir.path);

    expect(existing.readAsStringSync(), '{"family":"irodori_tts","new":true}');
  });

  test('creates the model directory when it does not exist yet', () async {
    final missing = p.join(tempDir.path, 'not', 'there');

    await installer('{"family":"irodori_tts"}').install(missing);

    expect(File(p.join(missing, 'irodori_tts.json')).existsSync(), isTrue);
  });

  // A spec that cannot be written must not stop synthesis: the engine may still
  // accept the request through its own contract, and failing the load outright
  // would take away a path that works today.
  test('a write failure is swallowed', () async {
    final blocked = IrodoriModelSpecInstaller(
      loadSpec: () async => throw StateError('asset missing'),
    );

    await expectLater(blocked.install(tempDir.path), completes);
    expect(
      File(p.join(tempDir.path, 'irodori_tts.json')).existsSync(),
      isFalse,
    );
  });
}
