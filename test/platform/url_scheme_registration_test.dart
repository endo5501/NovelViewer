import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/domain/download_request.dart';

/// Drift guard for the `novelviewer` URL scheme registration.
///
/// The registration lives in platform configuration rather than Dart, so
/// nothing else in the suite would notice it going missing: `flutter build`
/// and Xcode both rewrite parts of these files on their own, and the app keeps
/// working for everyone who never shares a link. What would break is the whole
/// entry point — a shared link would open nothing, with no error anywhere.
///
/// These assertions do not prove the OS delivers a link; only the manual
/// checklist in `docs/verify-url-scheme.md` can. They prove the registration
/// the change decided on is still in the files.
///
/// Modelled on `test/platform/ios_project_config_test.dart`, which guards the
/// rest of the iOS build configuration the same way.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path must exist');
    return file.readAsStringSync();
  }

  /// The schemes registered in a plist, flattened across every URL type.
  List<String> registeredSchemes(String plist) {
    final urlTypes = RegExp(
      r'<key>CFBundleURLTypes</key>\s*<array>(.*?)</array>\s*</dict>',
      dotAll: true,
    ).firstMatch(plist);
    if (urlTypes == null) return const [];
    return RegExp(
      r'<string>([^<]+)</string>',
    ).allMatches(urlTypes.group(1)!).map((m) => m.group(1)!).toList();
  }

  group('the scheme the app answers to', () {
    // The registration and the parser have to name the same scheme, and the
    // share extension planned for later will name it a third time. A rename
    // that reaches only one of them is silent.
    test('iOS registers the scheme the parser accepts', () {
      expect(
        registeredSchemes(read('ios/Runner/Info.plist')),
        contains(downloadRequestScheme),
      );
    });

    test('macOS registers the scheme the parser accepts', () {
      expect(
        registeredSchemes(read('macos/Runner/Info.plist')),
        contains(downloadRequestScheme),
      );
    });
  });

  group('platforms left out on purpose', () {
    // A scheme launch on Windows starts a second process, which would put two
    // of them on the same SQLite files. Registering the handler there is what
    // would trigger that, so the absence is the safeguard — and an absence is
    // exactly the kind of thing a later change removes without noticing.
    test('the Windows installer registers no scheme handler', () {
      final iss = read('installer/novel_viewer.iss');

      expect(iss, isNot(contains(downloadRequestScheme)));
      expect(iss.toLowerCase(), isNot(contains('urlprotocol')));
    });

    test('nothing registers a scheme handler at runtime on Windows', () {
      // The app already writes to the registry (the update check reads an
      // install type), so a handler could plausibly be added there.
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final source in sources) {
        final text = source.readAsStringSync();
        expect(
          text,
          isNot(contains('Software\\Classes')),
          reason: '${source.path} must not register a scheme handler',
        );
      }
    });
  });
}
