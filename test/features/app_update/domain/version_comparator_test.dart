import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/domain/version_comparator.dart';

void main() {
  group('isNewer', () {
    test('returns true when tag is strictly newer than current', () {
      expect(isNewer(current: '1.2.0', tagName: 'v1.2.1'), isTrue);
      expect(isNewer(current: '1.2.0', tagName: 'v2.0.0'), isTrue);
    });

    test('returns false when tag equals current', () {
      expect(isNewer(current: '1.2.0', tagName: 'v1.2.0'), isFalse);
    });

    test('returns false when tag is older than current', () {
      expect(isNewer(current: '1.2.0', tagName: 'v1.1.9'), isFalse);
    });

    test('strips a leading v from the tag before comparing', () {
      expect(isNewer(current: '1.0.0', tagName: 'v1.0.1'), isTrue);
      expect(isNewer(current: '1.0.0', tagName: '1.0.1'), isTrue);
    });

    test('returns false (no update) when the tag is not parseable', () {
      expect(isNewer(current: '1.0.0', tagName: 'v0.0.0-test1'), isFalse);
      expect(isNewer(current: '1.0.0', tagName: 'nightly'), isFalse);
      expect(isNewer(current: '1.0.0', tagName: ''), isFalse);
    });

    test('returns false when the current version is not parseable', () {
      expect(isNewer(current: 'unknown', tagName: 'v2.0.0'), isFalse);
    });

    test('ignores build metadata (1.2.3+4 is not newer than 1.2.3)', () {
      expect(isNewer(current: '1.2.3', tagName: 'v1.2.3+4'), isFalse);
      expect(isNewer(current: '1.2.3+5', tagName: 'v1.2.3'), isFalse);
      // build metadata must not mask a genuinely newer version
      expect(isNewer(current: '1.2.3', tagName: 'v1.2.4+1'), isTrue);
    });
  });
}
