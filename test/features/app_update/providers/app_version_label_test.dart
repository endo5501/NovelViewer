import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/shared/failure/sensitive_redaction.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _info = PackageInfo(
  appName: 'NovelViewer',
  packageName: 'com.example.novelViewer',
  version: '1.8.4',
  buildNumber: '19',
);

String _label({String? commit}) {
  final container = ProviderContainer(
    overrides: [
      packageInfoProvider.overrideWithValue(_info),
      if (commit != null) buildCommitProvider.overrideWithValue(commit),
    ],
  );
  addTearDown(container.dispose);
  return container.read(appVersionLabelProvider);
}

void main() {
  group('appVersionLabelProvider', () {
    test('a build given no identifier says so', () {
      expect(_label(commit: ''), '1.8.4+19 (commit unknown)');
    });

    test('a build given an identifier carries it', () {
      expect(_label(commit: 'a1b2c3d'), '1.8.4+19 (a1b2c3d)');
    });

    test('two builds of one release are told apart', () {
      expect(_label(commit: 'a1b2c3d'), isNot(_label(commit: 'e4f5a6b')));
    });

    test('the test build was given no identifier', () {
      // Nothing passes --dart-define to `flutter test`, so this is the value a
      // build made without the build scripts reports.
      expect(_label(), '1.8.4+19 (commit unknown)');
    });

    test('the identifier survives the report redaction', () {
      final label = _label(commit: 'a1b2c3d');

      expect(redactSensitive('app version: $label'), 'app version: $label');
    });
  });
}
