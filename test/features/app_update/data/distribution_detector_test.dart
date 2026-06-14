import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/app_update/data/distribution_detector.dart';
import 'package:novel_viewer/features/app_update/data/registry_reader.dart';
import 'package:novel_viewer/features/app_update/domain/distribution_type.dart';

class _FakeRegistryReader implements RegistryReader {
  _FakeRegistryReader({this.value, this.throwOnRead = false});

  final String? value;
  final bool throwOnRead;
  int readCount = 0;

  @override
  String? readString(String keyPath, String valueName) {
    readCount++;
    if (throwOnRead) throw StateError('registry unavailable');
    return value;
  }
}

void main() {
  group('DistributionDetector', () {
    test('returns installer when InstallType registry value is "installer"',
        () {
      final reader = _FakeRegistryReader(value: 'installer');
      final detector = DistributionDetector(
        registryReader: reader,
        isWindows: true,
      );

      expect(detector.detect(), DistributionType.installer);
    });

    test('returns portable when the registry key is missing (null value)', () {
      final reader = _FakeRegistryReader(value: null);
      final detector = DistributionDetector(
        registryReader: reader,
        isWindows: true,
      );

      expect(detector.detect(), DistributionType.portable);
    });

    test('returns portable when registry value is not "installer"', () {
      final reader = _FakeRegistryReader(value: 'something-else');
      final detector = DistributionDetector(
        registryReader: reader,
        isWindows: true,
      );

      expect(detector.detect(), DistributionType.portable);
    });

    test('returns portable and never reads the registry on non-Windows', () {
      final reader = _FakeRegistryReader(value: 'installer');
      final detector = DistributionDetector(
        registryReader: reader,
        isWindows: false,
      );

      expect(detector.detect(), DistributionType.portable);
      expect(reader.readCount, 0);
    });

    test('returns portable when the registry read throws', () {
      final reader = _FakeRegistryReader(throwOnRead: true);
      final detector = DistributionDetector(
        registryReader: reader,
        isWindows: true,
      );

      expect(detector.detect(), DistributionType.portable);
    });

    test('logs the registry-read failure at FINE (not WARNING) and falls back',
        () {
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(() {
        sub.cancel();
        Logger.root.level = previousLevel;
      });

      final reader = _FakeRegistryReader(throwOnRead: true);
      final detector = DistributionDetector(
        registryReader: reader,
        isWindows: true,
      );

      expect(detector.detect(), DistributionType.portable);

      final detected = records.where(
        (r) => r.loggerName == 'app_update.distribution',
      );
      expect(detected, isNotEmpty);
      // Expected fallback: must stay below the release threshold (Level.INFO)
      // so portable installs do not pollute the release log on every launch.
      expect(detected.every((r) => r.level < Level.INFO), isTrue);
    });
  });
}
