import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
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

final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(
  FontSizeNotifier.new,
);

class FontSizeNotifier extends Notifier<double> {
  @override
  double build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getFontSize();
  }

  void previewFontSize(double size) {
    state = size.clamp(SettingsRepository.minFontSize, SettingsRepository.maxFontSize);
  }

  Future<void> persistFontSize() async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setFontSize(state);
  }
}

final columnSpacingProvider = NotifierProvider<ColumnSpacingNotifier, double>(
  ColumnSpacingNotifier.new,
);

class ColumnSpacingNotifier extends Notifier<double> {
  @override
  double build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getColumnSpacing();
  }

  void previewColumnSpacing(double spacing) {
    state = spacing.clamp(
        SettingsRepository.minColumnSpacing, SettingsRepository.maxColumnSpacing);
  }

  Future<void> persistColumnSpacing() async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setColumnSpacing(state);
  }
}

final fontFamilyProvider = NotifierProvider<FontFamilyNotifier, FontFamily>(
  FontFamilyNotifier.new,
);

class FontFamilyNotifier extends Notifier<FontFamily> {
  @override
  FontFamily build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getFontFamily();
  }

  Future<void> setFontFamily(FontFamily family) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setFontFamily(family);
    state = family;
  }
}
