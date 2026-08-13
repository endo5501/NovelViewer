import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Writes the engine's model contract beside a downloaded Irodori model.
///
/// The engine validates request options against a model contract and rejects
/// anything the contract does not declare. Contract resolution prefers, in
/// order: an explicit override, the copy embedded in the GGUF, the workspace,
/// then the copy compiled into the runtime. A published GGUF therefore pins the
/// option list to whatever the package shipped with, which is older than the
/// runtime whenever the engine gains an option — `duration_correction` is the
/// current example.
///
/// The shim resolves `<model_dir>/irodori_tts.json` as an override, so writing
/// the contract there lifts it above the GGUF copy. On Windows the build script
/// also drops one next to the DLL, but macOS cannot: the Frameworks directory
/// is sealed by codesign and an extra file there breaks the signature. Writing
/// beside the model works on both, so it is the only mechanism used.
class IrodoriModelSpecInstaller {
  IrodoriModelSpecInstaller({Future<String> Function()? loadSpec})
      : _loadSpec = loadSpec ?? _loadBundledSpec;

  static const _assetPath = 'assets/model_specs/irodori_tts.json';

  /// File name the shim looks for inside the model directory.
  static const _fileName = 'irodori_tts.json';

  final Future<String> Function() _loadSpec;

  static final _log = Logger('tts.irodori.spec');

  static Future<String> _loadBundledSpec() => rootBundle.loadString(_assetPath);

  /// Writes the bundled contract into [modelDir], replacing any earlier copy.
  ///
  /// Always overwrites: the file wins over every other source of the contract,
  /// so a copy left by an older build would silently hold the engine to an
  /// older option list.
  ///
  /// Failures are logged and swallowed. The engine may still accept the request
  /// through its own contract — on Windows the copy beside the DLL covers it —
  /// and failing the model load outright would remove a path that works today.
  Future<void> install(String modelDir) async {
    try {
      final spec = await _loadSpec();
      final dir = Directory(modelDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      File(p.join(modelDir, _fileName)).writeAsStringSync(spec);
    } catch (error, stack) {
      _log.warning(
        'Failed to write the Irodori model spec into $modelDir; '
        'synthesis options may be rejected by the engine',
        error,
        stack,
      );
    }
  }
}
