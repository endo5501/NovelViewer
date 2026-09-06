import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drift guard for the iOS build configuration.
///
/// Almost everything that makes the app run on an iPad lives in Xcode
/// configuration rather than Dart, so it is invisible to the rest of the suite
/// and easy to lose: `flutter build ios` rewrites parts of the project on its
/// own, Xcode rewrites others whenever the project is opened, and a stray
/// `pod install` can reintroduce the CocoaPods integration that was
/// deliberately removed. None of that breaks a desktop build, so nothing else
/// would notice.
///
/// These assertions do not prove the app builds. They prove the decisions
/// recorded in the change are still in the files.
///
/// Modelled on `test/installer/windows_installer_files_test.dart`, which
/// guards the Inno Setup whitelist the same way.
void main() {
  late String infoPlist;
  late String pbxproj;
  late String debugXcconfig;
  late String releaseXcconfig;

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path must exist');
    return file.readAsStringSync();
  }

  /// Runs `git` with [args], or returns null when git is unavailable — a
  /// checkout without `.git`, or an image with no git installed. A missing git
  /// must not masquerade as a misconfigured project.
  ProcessResult? git(List<String> args) {
    try {
      return Process.runSync('git', args);
    } on ProcessException {
      return null;
    }
  }

  setUpAll(() {
    infoPlist = read('ios/Runner/Info.plist');
    pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
    debugXcconfig = read('ios/Flutter/Debug.xcconfig');
    releaseXcconfig = read('ios/Flutter/Release.xcconfig');
  });

  /// Returns the tag name of the value element that follows [key] in a plist,
  /// e.g. `true`, `false`, `string`, `dict`. Null when the key is absent.
  String? plistValueTag(String plist, String key) {
    final match = RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<([a-zA-Z]+)\\s*/?>',
    ).firstMatch(plist);
    return match?.group(1);
  }

  group('Files app exposure', () {
    // Without these two keys the library is sealed inside the sandbox: the
    // reader cannot add a text file by hand or copy one out, which is the only
    // way in on a build that has no sync mechanism.
    test('Info.plist enables file sharing', () {
      expect(
        plistValueTag(infoPlist, 'UIFileSharingEnabled'),
        'true',
        reason: 'UIFileSharingEnabled must be present and true',
      );
    });

    test('Info.plist supports opening documents in place', () {
      expect(
        plistValueTag(infoPlist, 'LSSupportsOpeningDocumentsInPlace'),
        'true',
        reason: 'LSSupportsOpeningDocumentsInPlace must be present and true',
      );
    });
  });

  group('device family', () {
    test('every build configuration targets iPad only', () {
      final assignments = RegExp(
        r'TARGETED_DEVICE_FAMILY = "?([0-9,]+)"?;',
      ).allMatches(pbxproj).map((m) => m.group(1)).toList();

      expect(
        assignments,
        isNotEmpty,
        reason: 'TARGETED_DEVICE_FAMILY must be set explicitly',
      );
      expect(
        assignments,
        everyElement('2'),
        reason:
            'iPhone is out of scope; "1" or "1,2" would ship an untested '
            'phone layout',
      );
    });

    test('iPad orientations stay unrestricted', () {
      final match = RegExp(
        r'<key>UISupportedInterfaceOrientations~ipad</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(infoPlist);

      expect(match, isNotNull, reason: 'the ~ipad orientation list must exist');
      final body = match!.group(1)!;
      for (final orientation in const [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ]) {
        expect(
          body,
          contains(orientation),
          reason: 'portrait reading must stay supported alongside landscape',
        );
      }
    });
  });

  group('Swift Package Manager is the only integration', () {
    test('no Podfile remains', () {
      expect(
        File('ios/Podfile').existsSync(),
        isFalse,
        reason:
            'every iOS plugin resolves as a Swift Package; a Podfile here '
            'only costs build time',
      );
      expect(File('ios/Podfile.lock').existsSync(), isFalse);
    });

    test('xcconfigs no longer include the Pods xcconfig', () {
      expect(debugXcconfig, isNot(contains('Pods/Target Support Files')));
      expect(releaseXcconfig, isNot(contains('Pods/Target Support Files')));
    });

    test('the workspace does not reference Pods.xcodeproj', () {
      final workspace = read('ios/Runner.xcworkspace/contents.xcworkspacedata');
      expect(workspace, isNot(contains('Pods.xcodeproj')));
    });

    // Xcode keeps a copy of the resolution in each container. Both are in the
    // tree, so a change made through one must not leave the other stale.
    const pinPaths = [
      'ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
      'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    ];

    test('the Swift Package pins are tracked', () {
      for (final path in pinPaths) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason:
              'Package.resolved pins the plugin dependencies, the way '
              'macos/Podfile.lock does for CocoaPods',
        );
        final tracked = git(['ls-files', '--error-unmatch', path]);
        if (tracked == null) continue;
        expect(
          tracked.exitCode,
          0,
          reason: '$path must be committed, not ignored',
        );
      }
    });

    test('the two pin files agree', () {
      final contents = pinPaths
          .map((path) => File(path).readAsStringSync())
          .toList();
      expect(
        contents[1],
        contents[0],
        reason:
            'a resolution updated through one container but not the other '
            'would pin different plugin versions depending on how the '
            'project is opened',
      );
    });

    test('macOS keeps its CocoaPods integration', () {
      // Dropping CocoaPods was an iOS-only decision. macOS is untouched.
      expect(File('macos/Podfile').existsSync(), isTrue);
      expect(File('macos/Podfile.lock').existsSync(), isTrue);
    });
  });

  group('signing identity stays out of the repository', () {
    test('xcconfigs optionally include the local override', () {
      // `#include?` rather than `#include`: a fresh clone has no
      // Local.xcconfig and must still configure.
      expect(debugXcconfig, contains('#include? "Local.xcconfig"'));
      expect(releaseXcconfig, contains('#include? "Local.xcconfig"'));
    });

    test('the local override is ignored by git', () {
      final ignored = git(['check-ignore', '-q', 'ios/Flutter/Local.xcconfig']);
      if (ignored == null) {
        markTestSkipped('git is not available');
        return;
      }
      expect(
        ignored.exitCode,
        0,
        reason:
            'a committed DEVELOPMENT_TEAM would collide with every other '
            'developer and land in the public history',
      );
    });

    test('no team identifier is committed', () {
      final assignments = RegExp(
        r'DEVELOPMENT_TEAM = ([^;]*);',
      ).allMatches(pbxproj).map((m) => m.group(1)!.trim()).toList();

      expect(
        assignments.where((v) => v.isNotEmpty && v != '""'),
        isEmpty,
        reason: 'DEVELOPMENT_TEAM belongs in the untracked Local.xcconfig',
      );
    });
  });

  group("Flutter's required migrations are committed", () {
    // A build applies these automatically. If they are not committed, every
    // build dirties the working tree.
    test('the UIScene lifecycle migration is in Info.plist', () {
      expect(plistValueTag(infoPlist, 'UIApplicationSceneManifest'), 'dict');
      expect(infoPlist, contains('FlutterSceneDelegate'));
    });

    test('the app delegate registers plugins via the implicit engine', () {
      final appDelegate = read('ios/Runner/AppDelegate.swift');
      expect(appDelegate, contains('FlutterImplicitEngineDelegate'));
      expect(appDelegate, contains('didInitializeImplicitFlutterEngine'));
    });
  });
}
