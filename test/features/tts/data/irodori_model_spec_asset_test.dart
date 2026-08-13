import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The bundled Irodori model contract must match the one in the engine it
/// validates against.
///
/// The engine rejects request options its contract does not declare, and the
/// contract embedded in a shipped GGUF outranks the one compiled into the
/// runtime. The app therefore writes this asset beside the downloaded model,
/// where the shim picks it up as a spec override and it outranks both.
///
/// That makes a stale asset dangerous rather than merely useless: it would
/// override a newer engine's contract with an older option list. This test is
/// the drift guard.
void main() {
  test('the bundled model spec matches the engine submodule copy', () {
    final asset = File('assets/model_specs/irodori_tts.json');
    final source = File('third_party/audio.cpp/model_specs/irodori_tts.json');

    expect(asset.existsSync(), isTrue, reason: '${asset.path} is missing');
    expect(
      source.existsSync(),
      isTrue,
      reason: '${source.path} is missing — is the submodule checked out?',
    );

    // Line endings are normalised because the two files live in different
    // repositories, so a checkout can apply different EOL rules to each. Only
    // the contract content matters here.
    String normalise(File file) =>
        file.readAsStringSync().replaceAll('\r\n', '\n');

    expect(
      normalise(asset),
      normalise(source),
      reason: 'Copy third_party/audio.cpp/model_specs/irodori_tts.json over '
          'assets/model_specs/irodori_tts.json after changing the engine '
          'contract. Shipping an older copy silently narrows the options the '
          'engine will accept.',
    );
  });
}
