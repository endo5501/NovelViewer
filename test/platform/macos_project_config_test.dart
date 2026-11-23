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

  /// The body of the Runner app target. Checking the whole project file is
  /// not enough: a reference that moved to RunnerTests, or a definition left
  /// behind after the target stopped using it, would still match.
  String runnerTarget() {
    final match = RegExp(
      r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;(.*?)\n\t\t\};',
      dotAll: true,
    ).firstMatch(pbxproj);
    expect(match, isNotNull, reason: 'the Runner target must exist');
    return match!.group(1)!;
  }

  /// The entries of the Runner target's buildPhases list.
  String runnerBuildPhases() {
    final match = RegExp(
      r'buildPhases = \((.*?)\);',
      dotAll: true,
    ).firstMatch(runnerTarget());
    expect(match, isNotNull, reason: 'Runner must list its build phases');
    return match!.group(1)!;
  }

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
      // Pods_Runner also covers Pods_RunnerTests.
      expect(pbxproj, isNot(contains('Pods_Runner')));
      expect(pbxproj, isNot(contains('Pods-Runner')));
      expect(pbxproj, isNot(contains('PODS_ROOT')));
      expect(pbxproj, isNot(contains('[CP]')));
    });

    test('Runner still links the generated Swift Package', () {
      expect(
        runnerTarget(),
        contains('/* FlutterGeneratedPluginSwiftPackage */'),
        reason: 'Runner must depend on the package product',
      );

      final frameworksId = RegExp(
        r'([0-9A-F]{24}) /\* Frameworks \*/',
      ).firstMatch(runnerBuildPhases())?.group(1);
      expect(frameworksId, isNotNull, reason: 'Runner has a Frameworks phase');
      final frameworks = RegExp(
        '$frameworksId /\\* Frameworks \\*/ = \\{(.*?)\\n\\t\\t\\};',
        dotAll: true,
      ).firstMatch(pbxproj);
      expect(frameworks, isNotNull);
      expect(
        frameworks!.group(1),
        contains('/* FlutterGeneratedPluginSwiftPackage in Frameworks */'),
        reason: 'the plugins are linked through this phase',
      );
    });
  });

  group('native-library embedding survives without CocoaPods', () {
    test('the Embed Native Libraries phase still copies the dylibs', () {
      final phase = RegExp(
        r'/\* Embed Native Libraries \*/ = \{(.*?)\n\t\t\};',
        dotAll: true,
      ).firstMatch(pbxproj);
      expect(phase, isNotNull, reason: 'the embed phase must exist');
      expect(phase!.group(1), contains(r'\"${SRCROOT}\"/Frameworks/*.dylib'));
    });

    test('the Embed Native Libraries phase runs in the Runner target', () {
      expect(runnerBuildPhases(), contains('/* Embed Native Libraries */'));
    });
  });
}
