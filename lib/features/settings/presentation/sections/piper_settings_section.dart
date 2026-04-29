import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/data/piper_model_download_service.dart';
import 'package:novel_viewer/features/tts/providers/piper_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class PiperSettingsSection extends ConsumerWidget {
  const PiperSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PiperModelSelector(),
        SizedBox(height: 16),
        _PiperModelDownloadSection(),
        SizedBox(height: 16),
        Divider(),
        SizedBox(height: 8),
        _PiperSynthesisParams(),
      ],
    );
  }
}

class _PiperModelSelector extends ConsumerWidget {
  const _PiperModelSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final modelName = ref.watch(piperModelNameProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        initialValue: modelName,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.settings_modelLabel,
        ),
        items: const [
          DropdownMenuItem(
            value: PiperModelDownloadService.defaultModelName,
            child: Text(PiperModelDownloadService.defaultModelName),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            ref
                .read(piperModelNameProvider.notifier)
                .setPiperModelName(value);
          }
        },
      ),
    );
  }
}

class _PiperModelDownloadSection extends ConsumerWidget {
  const _PiperModelDownloadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final downloadState = ref.watch(piperModelDownloadProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: switch (downloadState) {
        PiperModelDownloadIdle() => ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: Text(l10n.settings_modelDataDownload),
            onPressed: () {
              ref.read(piperModelDownloadProvider.notifier).startDownload();
            },
          ),
        PiperModelDownloadDownloading(:final currentFile, :final progress) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(currentFile),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              if (progress != null)
                Text('${(progress * 100).toStringAsFixed(1)}%'),
            ],
          ),
        PiperModelDownloadCompleted(:final modelsDir) => Row(
            children: [
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.settings_piperDownloaded}${modelsDir != null ? '\n$modelsDir' : ''}',
                ),
              ),
            ],
          ),
        PiperModelDownloadError(:final message) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(piperModelDownloadProvider.notifier)
                      .startDownload();
                },
                child: Text(l10n.settings_retryButton),
              ),
            ],
          ),
      },
    );
  }
}

class _PiperSynthesisParams extends ConsumerWidget {
  const _PiperSynthesisParams();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lengthScale = ref.watch(piperLengthScaleProvider);
    final noiseScale = ref.watch(piperNoiseScaleProvider);
    final noiseW = ref.watch(piperNoiseWProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.settings_piperLengthScale}: ${lengthScale.toStringAsFixed(1)}'),
          Slider(
            value: lengthScale,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: lengthScale.toStringAsFixed(1),
            onChanged: (value) {
              ref.read(piperLengthScaleProvider.notifier).setValue(value);
            },
          ),
          const SizedBox(height: 8),
          Text('${l10n.settings_piperNoiseScale}: ${noiseScale.toStringAsFixed(3)}'),
          Slider(
            value: noiseScale,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: noiseScale.toStringAsFixed(3),
            onChanged: (value) {
              ref.read(piperNoiseScaleProvider.notifier).setValue(value);
            },
          ),
          const SizedBox(height: 8),
          Text('${l10n.settings_piperNoiseW}: ${noiseW.toStringAsFixed(3)}'),
          Slider(
            value: noiseW,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: noiseW.toStringAsFixed(3),
            onChanged: (value) {
              ref.read(piperNoiseWProvider.notifier).setValue(value);
            },
          ),
        ],
      ),
    );
  }
}
