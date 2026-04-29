import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';
import 'package:novel_viewer/features/tts/data/tts_model_size.dart';
import 'package:novel_viewer/features/tts/providers/tts_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class Qwen3SettingsSection extends ConsumerWidget {
  const Qwen3SettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LanguageSelector(),
        SizedBox(height: 16),
        _ModelSizeSelector(),
        SizedBox(height: 16),
        _ModelDownloadSection(),
      ],
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final language = ref.watch(ttsLanguageProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<TtsLanguage>(
        initialValue: language,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.settings_ttsLanguageLabel,
        ),
        items: TtsLanguage.values.map((lang) {
          return DropdownMenuItem(
            value: lang,
            child: Text(lang.displayName),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            ref.read(ttsLanguageProvider.notifier).setLanguage(value);
          }
        },
      ),
    );
  }
}

class _ModelSizeSelector extends ConsumerWidget {
  const _ModelSizeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final modelSize = ref.watch(ttsModelSizeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_voiceModelTitle,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TtsModelSize>(
              segments: [
                ButtonSegment(
                  value: TtsModelSize.small,
                  label: Text(l10n.settings_voiceModelSmall),
                ),
                ButtonSegment(
                  value: TtsModelSize.large,
                  label: Text(l10n.settings_voiceModelLarge),
                ),
              ],
              selected: {modelSize},
              onSelectionChanged: (selected) {
                ref
                    .read(ttsModelSizeProvider.notifier)
                    .setTtsModelSize(selected.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelDownloadSection extends ConsumerWidget {
  const _ModelDownloadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final downloadState = ref.watch(ttsModelDownloadProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: switch (downloadState) {
        TtsModelDownloadIdle() => ElevatedButton.icon(
            onPressed: () {
              ref.read(ttsModelDownloadProvider.notifier).startDownload();
            },
            icon: const Icon(Icons.download),
            label: Text(l10n.settings_modelDataDownload),
          ),
        TtsModelDownloadDownloading(:final currentFile, :final progress) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentFile.isNotEmpty)
                Text(currentFile, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress),
              if (progress != null)
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        TtsModelDownloadCompleted(:final modelsDir) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n.settings_modelDownloadCompleted),
                ],
              ),
              if (modelsDir != null) ...[
                const SizedBox(height: 4),
                Text(
                  modelsDir,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        TtsModelDownloadError(:final message) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.common_errorPrefix(message),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.read(ttsModelDownloadProvider.notifier).startDownload();
                },
                child: Text(l10n.settings_retryButton),
              ),
            ],
          ),
      },
    );
  }
}
