import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Inno Setup [Files] whitelist against packaging regressions.
///
/// The installer ships an explicit whitelist (exe / *.dll / licenses / data),
/// so any runtime support file that lives outside those globs is silently
/// dropped from installed copies while ZIP builds (which archive the whole
/// Release tree) keep working. That is exactly how `model_specs\` went
/// missing: the Irodori shim resolves `model_specs/irodori_tts.json` next to
/// audiocpp_ffi.dll and failed with "model package spec not found" only on
/// installer-based installs.
void main() {
  late String iss;

  setUpAll(() {
    final file = File('installer/novel_viewer.iss');
    expect(file.existsSync(), isTrue,
        reason: 'installer/novel_viewer.iss must exist');
    iss = file.readAsStringSync();
  });

  group('Inno Setup [Files] section', () {
    test('packages the Irodori model spec directory', () {
      final line = iss
          .split('\n')
          .map((l) => l.trim())
          .firstWhere(
            (l) => l.startsWith('Source:') && l.contains(r'model_specs'),
            orElse: () => '',
          );

      expect(
        line,
        isNotEmpty,
        reason: 'The installer must package the model_specs directory; '
            'without it Irodori-TTS fails with "model package spec not found '
            "for family 'irodori_tts'\".",
      );
      expect(
        line,
        contains(r'..\build\windows\x64\runner\Release\model_specs\*'),
        reason: 'model_specs must be sourced from the Release build output',
      );
      expect(
        line,
        contains(r'DestDir: "{app}\model_specs"'),
        reason: 'The shim resolves model_specs/ next to the DLL, i.e. {app}',
      );
      expect(
        line,
        contains('recursesubdirs'),
        reason: 'Ship the whole spec tree, not just its top level',
      );
    });
  });
}
