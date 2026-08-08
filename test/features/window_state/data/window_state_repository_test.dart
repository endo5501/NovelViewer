import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/window_state/data/window_state_repository.dart';
import 'package:novel_viewer/features/window_state/domain/window_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<void> initPrefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  group('WindowStateRepository - load', () {
    test('returns empty state when no keys are stored', () async {
      await initPrefs();
      expect(WindowStateRepository(prefs).load(), WindowState.empty);
    });

    test('reads a previously stored size and maximized flag', () async {
      await initPrefs({
        'window_width': 1600.0,
        'window_height': 1000.0,
        'window_maximized': true,
      });
      expect(
        WindowStateRepository(prefs).load(),
        const WindowState(width: 1600, height: 1000, maximized: true),
      );
    });

    test('defaults maximized to false when the flag is absent', () async {
      await initPrefs({'window_width': 1600.0, 'window_height': 1000.0});
      final state = WindowStateRepository(prefs).load();
      expect(state.maximized, isFalse);
      expect(state.hasSize, isTrue);
    });

    test('drops the size when only one axis is stored', () async {
      await initPrefs({'window_width': 1600.0});
      expect(WindowStateRepository(prefs).load().hasSize, isFalse);
    });

    test('rejects a negative width', () async {
      await initPrefs({'window_width': -1600.0, 'window_height': 1000.0});
      expect(WindowStateRepository(prefs).load().hasSize, isFalse);
    });

    test('rejects a zero height', () async {
      await initPrefs({'window_width': 1600.0, 'window_height': 0.0});
      expect(WindowStateRepository(prefs).load().hasSize, isFalse);
    });

    test('rejects a non-finite value', () async {
      await initPrefs({
        'window_width': double.infinity,
        'window_height': 1000.0,
      });
      expect(WindowStateRepository(prefs).load().hasSize, isFalse);
    });

    // getDouble throws (rather than returning null) when the key holds another
    // type, so the repository has to catch it instead of propagating.
    test('falls back to empty when a key holds a non-numeric type', () async {
      await initPrefs({'window_width': 'abc', 'window_height': 1000.0});
      expect(WindowStateRepository(prefs).load(), WindowState.empty);
    });

    test('falls back to empty when the maximized flag holds a wrong type',
        () async {
      await initPrefs({
        'window_width': 1600.0,
        'window_height': 1000.0,
        'window_maximized': 'yes',
      });
      expect(WindowStateRepository(prefs).load(), WindowState.empty);
    });
  });

  group('WindowStateRepository - save', () {
    test('save then load round-trips a normal window', () async {
      await initPrefs();
      final repo = WindowStateRepository(prefs);
      await repo.save(const WindowState(width: 1600, height: 1000));
      expect(
        repo.load(),
        const WindowState(width: 1600, height: 1000, maximized: false),
      );
    });

    test('save then load round-trips a maximized window', () async {
      await initPrefs();
      final repo = WindowStateRepository(prefs);
      await repo.save(
        const WindowState(width: 1400, height: 900, maximized: true),
      );
      expect(
        repo.load(),
        const WindowState(width: 1400, height: 900, maximized: true),
      );
    });

    test('saving only the maximized flag keeps the stored size intact',
        () async {
      await initPrefs({'window_width': 1400.0, 'window_height': 900.0});
      final repo = WindowStateRepository(prefs);
      await repo.saveMaximized(true);
      expect(
        repo.load(),
        const WindowState(width: 1400, height: 900, maximized: true),
      );
    });

    test('writes the documented preference keys', () async {
      await initPrefs();
      await WindowStateRepository(prefs)
          .save(const WindowState(width: 1600, height: 1000, maximized: true));
      expect(prefs.getDouble('window_width'), 1600.0);
      expect(prefs.getDouble('window_height'), 1000.0);
      expect(prefs.getBool('window_maximized'), isTrue);
    });
  });
}
