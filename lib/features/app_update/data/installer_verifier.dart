import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

final _log = Logger('app_update.verifier');

/// Verifies a downloaded installer against its `.sha256` sidecar.
class InstallerVerifier {
  const InstallerVerifier();

  Future<bool> verify({
    required String exePath,
    required String sha256Path,
  }) async {
    try {
      final expected =
          _parseExpectedHash(await File(sha256Path).readAsString());
      if (expected == null) return false;
      final bytes = await File(exePath).readAsBytes();
      final actual = sha256.convert(bytes).toString().toLowerCase();
      return actual == expected;
    } catch (e, stack) {
      // Missing/unreadable files mean we cannot trust the download. This is an
      // anomaly that aborts the update, so surface it at WARNING.
      _log.warning('Failed to read verification input: $e', e, stack);
      return false;
    }
  }

  /// Sidecar format is `<64-hex-hash>  <filename>`; we only need the hash.
  String? _parseExpectedHash(String content) {
    final firstToken = content.trim().split(RegExp(r'\s+')).first;
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(firstToken)) return null;
    return firstToken.toLowerCase();
  }
}
