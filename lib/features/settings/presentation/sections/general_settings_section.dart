import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class GeneralSettingsSection extends ConsumerWidget {
  const GeneralSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final displayMode = ref.watch(displayModeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);
    final columnSpacing = ref.watch(columnSpacingProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(l10n.settings_languageTitle),
          subtitle: DropdownButton<Locale>(
            value: locale,
            isExpanded: true,
            onChanged: (value) {
              if (value != null) {
                ref.read(localeProvider.notifier).setLocale(value);
              }
            },
            items: const [
              DropdownMenuItem(
                value: Locale('ja'),
                child: Text('日本語'),
              ),
              DropdownMenuItem(
                value: Locale('en'),
                child: Text('English'),
              ),
              DropdownMenuItem(
                value: Locale('zh'),
                child: Text('中文'),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: Text(l10n.settings_verticalDisplayTitle),
          subtitle: Text(
            displayMode == TextDisplayMode.vertical
                ? l10n.settings_verticalDisplayVertical
                : l10n.settings_verticalDisplayHorizontal,
          ),
          value: displayMode == TextDisplayMode.vertical,
          onChanged: (value) {
            ref.read(displayModeProvider.notifier).setMode(
                  value
                      ? TextDisplayMode.vertical
                      : TextDisplayMode.horizontal,
                );
          },
        ),
        SwitchListTile(
          title: Text(l10n.settings_darkModeTitle),
          subtitle: Text(
            themeMode == ThemeMode.dark
                ? l10n.settings_darkModeDark
                : l10n.settings_darkModeLight,
          ),
          value: themeMode == ThemeMode.dark,
          onChanged: (value) {
            ref.read(themeModeProvider.notifier).setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
          },
        ),
        ListTile(
          title: Text(l10n.settings_fontSizeTitle),
          subtitle: Slider(
            value: fontSize,
            min: SettingsRepository.minFontSize,
            max: SettingsRepository.maxFontSize,
            divisions: (SettingsRepository.maxFontSize -
                    SettingsRepository.minFontSize)
                .toInt(),
            label: fontSize.toStringAsFixed(1),
            onChanged: (value) {
              ref.read(fontSizeProvider.notifier).previewFontSize(value);
            },
            onChangeEnd: (_) {
              ref.read(fontSizeProvider.notifier).persistFontSize();
            },
          ),
          trailing: Text(fontSize.toStringAsFixed(1)),
        ),
        ListTile(
          title: Text(l10n.settings_fontFamilyTitle),
          subtitle: DropdownButton<FontFamily>(
            value: fontFamily,
            isExpanded: true,
            onChanged: (value) {
              if (value != null) {
                ref.read(fontFamilyProvider.notifier).setFontFamily(value);
              }
            },
            items: FontFamily.availableFonts.map((family) {
              return DropdownMenuItem<FontFamily>(
                value: family,
                child: Text(family.displayName),
              );
            }).toList(),
          ),
        ),
        ListTile(
          title: Text(l10n.settings_columnSpacingTitle),
          subtitle: Slider(
            value: columnSpacing,
            min: SettingsRepository.minColumnSpacing,
            max: SettingsRepository.maxColumnSpacing,
            divisions: (SettingsRepository.maxColumnSpacing -
                    SettingsRepository.minColumnSpacing)
                .toInt(),
            label: columnSpacing.toStringAsFixed(1),
            onChanged: (value) {
              ref
                  .read(columnSpacingProvider.notifier)
                  .previewColumnSpacing(value);
            },
            onChangeEnd: (_) {
              ref
                  .read(columnSpacingProvider.notifier)
                  .persistColumnSpacing();
            },
          ),
          trailing: Text(columnSpacing.toStringAsFixed(1)),
        ),
      ],
    );
  }
}
