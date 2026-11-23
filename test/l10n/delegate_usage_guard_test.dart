import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// gen-l10n's `AppLocalizations.localizationsDelegates` wires the deprecated
/// flutter_localizations delegates, whose localization types material_ui
/// widgets never look up. The generated file is excluded from analysis, so
/// nothing else flags a MaterialApp that goes back to it; every app and test
/// must use `appLocalizationsDelegates` instead.
void main() {
  test('no hand-written code uses the generated delegate list', () {
    final generated = RegExp(
      r'lib[\\/]l10n[\\/]app_localizations(_\w+)?\.dart$',
    );
    final offenders = <String>[];
    for (final root in ['lib', 'test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (generated.hasMatch(entity.path)) continue;
        if (entity.path.endsWith('delegate_usage_guard_test.dart')) continue;
        if (entity.readAsStringSync().contains(
          'AppLocalizations.localizationsDelegates',
        )) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
