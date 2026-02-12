import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});

final displayModeProvider =
    NotifierProvider<DisplayModeNotifier, TextDisplayMode>(
  DisplayModeNotifier.new,
);

class DisplayModeNotifier extends Notifier<TextDisplayMode> {
  @override
  TextDisplayMode build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getDisplayMode();
  }

  Future<void> setMode(TextDisplayMode mode) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setDisplayMode(mode);
    state = mode;
  }
}
