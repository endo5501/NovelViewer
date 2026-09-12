import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drift guard for the generated app icons.
///
/// The icons are produced by `dart run flutter_launcher_icons` from the single
/// source image `assets/app_icon.png` and committed to the repository. Nothing
/// in the Dart code references them, so when a platform is missing from the
/// `flutter_launcher_icons` configuration its icons simply stay as the Flutter
/// template's defaults and every other test still passes. That is exactly how
/// the iPad build shipped with the default Flutter icon.
///
/// These assertions do not prove the icon looks right. They prove the
/// configuration covers all four platforms, that the generated files are
/// present and in a form the platforms accept, and that no platform has been
/// left on the template's default artwork.
///
/// Modelled on `test/platform/ios_project_config_test.dart`, which guards the
/// Xcode project the same way.
void main() {
  const iosIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const androidResDir = 'android/app/src/main/res';
  const androidDensities = <String>[
    'mdpi',
    'hdpi',
    'xhdpi',
    'xxhdpi',
    'xxxhdpi',
  ];

  /// SHA-256 of the Flutter template's default icons, as introduced by the
  /// project's initialisation commit `316420f5`.
  ///
  /// The assertion is that the committed icons differ from these. Pinning the
  /// hash of the *expected* icons instead would break whenever the source
  /// artwork is redesigned or the PNG encoder changes its output; these bytes,
  /// being history, never change.
  const flutterDefaultIconHashes = <String, String>{
    '$iosIconDir/Icon-App-1024x1024@1x.png':
        '7770183009e914112de7d8ef1d235a6a30c5834424858e0d2f8253f6b8d31926',
    '$androidResDir/mipmap-mdpi/ic_launcher.png':
        'c7c0c0189145e4e32a401c61c9bdc615754b0264e7afae24e834bb81049eaf81',
    '$androidResDir/mipmap-hdpi/ic_launcher.png':
        '6a7c8f0d703e3682108f9662f813302236240d3f8f638bb391e32bfb96055fef',
    '$androidResDir/mipmap-xhdpi/ic_launcher.png':
        'e14aa40904929bf313fded22cf7e7ffcbf1d1aac4263b5ef1be8bfce650397aa',
    '$androidResDir/mipmap-xxhdpi/ic_launcher.png':
        '4d470bf22d5c17d84edc5f82516d1ba8a1c09559cd761cefb792f86d9f52b540',
    '$androidResDir/mipmap-xxxhdpi/ic_launcher.png':
        '3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180',
  };

  File requireFile(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path must exist');
    return file;
  }

  /// Flattens the `flutter_launcher_icons` block of `pubspec.yaml` into
  /// dotted-path entries such as `macos.generate` -> `true`.
  ///
  /// Reading it by hand keeps the test off `package:yaml`, which the project
  /// only pulls in transitively.
  Map<String, String> launcherIconsConfig(String pubspec) {
    final lines = pubspec.split('\n');
    final start = lines.indexWhere(
      (line) => line.trimRight() == 'flutter_launcher_icons:',
    );
    expect(
      start,
      isNonNegative,
      reason: 'pubspec.yaml must declare a flutter_launcher_icons section',
    );

    final config = <String, String>{};
    final openKeys = <int, String>{};
    for (final raw in lines.skip(start + 1)) {
      // A line without leading whitespace ends the block.
      if (raw.trim().isNotEmpty && !raw.startsWith(' ')) {
        break;
      }
      final line = raw.split('#').first.trimRight();
      if (line.trim().isEmpty) {
        continue;
      }
      final indent = line.length - line.trimLeft().length;
      final content = line.trim();
      final separator = content.indexOf(':');
      if (separator < 0) {
        continue;
      }
      final key = content.substring(0, separator).trim();
      final value = content.substring(separator + 1).trim();

      openKeys.removeWhere((keyIndent, _) => keyIndent >= indent);
      final parents = (openKeys.keys.toList()..sort())
          .map((keyIndent) => openKeys[keyIndent])
          .join('.');
      final path = parents.isEmpty ? key : '$parents.$key';

      if (value.isEmpty) {
        openKeys[indent] = key;
      } else {
        config[path] = value.replaceAll('"', '').replaceAll("'", '');
      }
    }
    return config;
  }

  /// Whether a PNG carries an alpha channel, read from the colour type byte of
  /// the IHDR chunk. Colour types 4 and 6 are the ones with alpha.
  ///
  /// The header sits at a fixed offset, so this avoids depending on an image
  /// decoding library just to answer one question.
  bool pngHasAlpha(String path, List<int> bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    expect(
      bytes.take(signature.length),
      orderedEquals(signature),
      reason: '$path must be a PNG',
    );
    expect(
      utf8.decode(bytes.sublist(12, 16)),
      'IHDR',
      reason: '$path must start with an IHDR chunk',
    );
    final colourType = bytes[25];
    return colourType == 4 || colourType == 6;
  }

  group('flutter_launcher_icons configuration', () {
    late Map<String, String> config;

    setUpAll(() {
      config = launcherIconsConfig(
        requireFile('pubspec.yaml').readAsStringSync(),
      );
    });

    test('generates from the single source image', () {
      expect(config['image_path'], 'assets/app_icon.png');
      expect(requireFile('assets/app_icon.png').existsSync(), isTrue);
    });

    test('covers all four platforms', () {
      expect(config['macos.generate'], 'true', reason: 'macOS must be enabled');
      expect(
        config['windows.generate'],
        'true',
        reason: 'Windows must be enabled',
      );
      expect(config['ios'], 'true', reason: 'iOS must be enabled');
      expect(config['android'], 'true', reason: 'Android must be enabled');
    });

    test('strips alpha from the iOS icons', () {
      expect(config['remove_alpha_ios'], 'true');
    });
  });

  group('iOS app icon', () {
    late List<String> declaredFilenames;

    setUpAll(() {
      final contents =
          jsonDecode(
                requireFile('$iosIconDir/Contents.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final images = contents['images'] as List<dynamic>;
      declaredFilenames = images
          .map(
            (image) => (image as Map<String, dynamic>)['filename'] as String?,
          )
          .whereType<String>()
          .toList();
    });

    test('declares the App Store icon', () {
      expect(declaredFilenames, contains('Icon-App-1024x1024@1x.png'));
    });

    test('every declared icon exists on disk', () {
      expect(declaredFilenames, isNotEmpty);
      for (final filename in declaredFilenames) {
        requireFile('$iosIconDir/$filename');
      }
    });

    test('no icon carries an alpha channel', () {
      for (final filename in declaredFilenames) {
        final path = '$iosIconDir/$filename';
        expect(
          pngHasAlpha(path, requireFile(path).readAsBytesSync()),
          isFalse,
          reason: '$path must not have an alpha channel',
        );
      }
    });
  });

  group('Android launcher icon', () {
    test('exists for every density', () {
      for (final density in androidDensities) {
        requireFile('$androidResDir/mipmap-$density/ic_launcher.png');
      }
    });
  });

  group('Xcode project survives icon generation', () {
    /// `flutter_launcher_icons` 0.14.4 rewrites every line of the pbxproj that
    /// contains `ASSETCATALOG` to `= AppIcon;`, which turns this boolean
    /// setting into an invalid value. `ASSETCATALOG_COMPILER_APPICON_NAME` is
    /// already `AppIcon`, so the project needs no change at all and the file
    /// must be reverted after each generation run.
    test('the asset symbol setting is still a boolean', () {
      final pbxproj = requireFile(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final matches = RegExp(
        r'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = (\w+);',
      ).allMatches(pbxproj);

      expect(matches, isNotEmpty);
      for (final match in matches) {
        expect(
          match.group(1),
          anyOf('YES', 'NO'),
          reason:
              'flutter_launcher_icons corrupted the Xcode project. '
              'Revert ios/Runner.xcodeproj/project.pbxproj after generating.',
        );
      }
    });
  });

  group('generated icons replace the Flutter defaults', () {
    test('no platform still ships the template artwork', () {
      flutterDefaultIconHashes.forEach((path, defaultHash) {
        final actual = sha256
            .convert(requireFile(path).readAsBytesSync())
            .toString();
        expect(
          actual,
          isNot(defaultHash),
          reason:
              '$path is still the Flutter template default. '
              'Run `dart run flutter_launcher_icons` and commit the result.',
        );
      });
    });
  });
}
