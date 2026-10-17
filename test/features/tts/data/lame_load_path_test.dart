import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drift guard: the LAME encoder is loaded only by an MP3 export, and an
/// export is started only from the controls bar's export button, which is
/// absent where export is unsupported (spec tts-audio-export). So on iOS,
/// which has no LAME build, the library is never loaded.
///
/// Opening the library or starting an export from anywhere else would bypass
/// that gate; this test fails if either appears elsewhere in lib/.
void main() {
  List<String> filesContaining(String needle) => [
    for (final file in Directory('lib').listSync(recursive: true))
      if (file is File &&
          file.path.endsWith('.dart') &&
          file.readAsStringSync().contains(needle))
        file.path.replaceAll(r'\', '/'),
  ]..sort();

  test('only the export service opens the LAME library', () {
    // lame_enc_bindings.dart is where the factory is declared.
    expect(
      filesContaining(
        'LameEncBindings.open(',
      ).where((f) => !f.endsWith('lame_enc_bindings.dart')).toList(),
      ['lib/features/tts/data/tts_audio_export_service.dart'],
    );
  });

  test('only the controls bar starts an MP3 export', () {
    expect(
      filesContaining(
        'exportEpisodeToMp3(',
      ).where((f) => !f.endsWith('tts_export_providers.dart')).toList(),
      ['lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart'],
    );
    expect(
      filesContaining(
        'exportToMp3WithProgress(',
      ).where((f) => !f.endsWith('tts_audio_export_service.dart')).toList(),
      ['lib/features/tts/providers/tts_export_providers.dart'],
    );
  });
}
