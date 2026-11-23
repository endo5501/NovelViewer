import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drift guard for the macOS dependency integration.
///
/// Every plugin resolves as a Swift Package on macOS, so the CocoaPods
/// integration was removed. A stray `pod install` (or an old checkout's
/// Podfile coming back through a merge) would quietly reintroduce it, and the
/// build would still succeed, so nothing else would notice.
///
/// The Podfile's `post_install` hook was also what first added the
/// "Embed Native Libraries" phase. That phase now lives in the Xcode project
/// on its own; these tests make sure dropping CocoaPods did not take it along.
void main() {
  late String pbxproj;

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path must exist');
    return file.readAsStringSync();
  }

  setUpAll(() {
    pbxproj = read('macos/Runner.xcodeproj/project.pbxproj');
  });

  group('Swift Package Manager is the only integration', () {
    test('no Podfile remains', () {
      expect(
        File('macos/Podfile').existsSync(),
        isFalse,
        reason:
            'every macOS plugin resolves as a Swift Package; a Podfile here '
            'makes flutter run pod install on every build',
      );
      expect(File('macos/Podfile.lock').existsSync(), isFalse);
    });

    test('xcconfigs no longer include the Pods xcconfig', () {
      for (final path in [
        'macos/Flutter/Flutter-Debug.xcconfig',
        'macos/Flutter/Flutter-Release.xcconfig',
      ]) {
        expect(
          read(path),
          isNot(contains('Pods/Target Support Files')),
          reason: path,
        );
      }
    });

    test('the workspace does not reference Pods.xcodeproj', () {
      final workspace = read(
        'macos/Runner.xcworkspace/contents.xcworkspacedata',
      );
      expect(workspace, isNot(contains('Pods.xcodeproj')));
    });

    test('the Xcode project carries no CocoaPods residue', () {
      expect(pbxproj, isNot(contains('Pods_Runner')));
      expect(pbxproj, isNot(contains('Pods_RunnerTests')));
      expect(pbxproj, isNot(contains('Pods-Runner')));
      expect(pbxproj, isNot(contains('[CP]')));
    });

    test('plugins still resolve through the generated Swift Package', () {
      expect(
        pbxproj,
        contains('FlutterGeneratedPluginSwiftPackage in Frameworks'),
      );
    });
  });

  group('native-library embedding survives without CocoaPods', () {
    test('the Embed Native Libraries phase is still in the project', () {
      // The definition, and the entry in a target's buildPhases list that runs it.
      expect(pbxproj, contains('/* Embed Native Libraries */ = {'));
      expect(pbxproj, contains('/* Embed Native Libraries */,'));
      expect(pbxproj, contains(r'\"${SRCROOT}\"/Frameworks/*.dylib'));
    });
  });
}
