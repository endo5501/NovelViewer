import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/data/font_family.dart';
import 'package:novel_viewer/features/settings/data/settings_repository.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = ref.watch(displayModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);

    return AlertDialog(
      title: const Text('設定'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('縦書き表示'),
              subtitle: Text(
                displayMode == TextDisplayMode.vertical ? '縦書き' : '横書き',
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
            ListTile(
              title: const Text('フォントサイズ'),
              subtitle: Slider(
                value: fontSize,
                min: SettingsRepository.minFontSize,
                max: SettingsRepository.maxFontSize,
                divisions: (SettingsRepository.maxFontSize - SettingsRepository.minFontSize).toInt(),
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
              title: const Text('フォント種別'),
              subtitle: DropdownButton<FontFamily>(
                value: fontFamily,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(fontFamilyProvider.notifier)
                        .setFontFamily(value);
                  }
                },
                items: FontFamily.values.map((family) {
                  return DropdownMenuItem<FontFamily>(
                    value: family,
                    child: Text(family.displayName),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
