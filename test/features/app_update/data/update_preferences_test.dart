import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/app_update/data/update_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<UpdatePreferences> build([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return UpdatePreferences(prefs);
  }

  group('autoCheckEnabled', () {
    test('defaults to true when unset', () async {
      final prefs = await build();
      expect(prefs.autoCheckEnabled, isTrue);
    });

    test('persists a false value', () async {
      final prefs = await build();
      await prefs.setAutoCheckEnabled(false);
      expect(prefs.autoCheckEnabled, isFalse);
    });
  });

  group('lastCheckAt', () {
    test('is null when unset', () async {
      final prefs = await build();
      expect(prefs.lastCheckAt, isNull);
    });

    test('round-trips a timestamp', () async {
      final prefs = await build();
      final now = DateTime.utc(2026, 5, 28, 12, 0, 0);
      await prefs.setLastCheckAt(now);
      expect(prefs.lastCheckAt, now);
    });
  });

  group('dismissedVersion', () {
    test('is null when unset', () async {
      final prefs = await build();
      expect(prefs.dismissedVersion, isNull);
    });

    test('round-trips a version string', () async {
      final prefs = await build();
      await prefs.setDismissedVersion('1.2.0');
      expect(prefs.dismissedVersion, '1.2.0');
    });
  });
}
