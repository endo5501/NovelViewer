import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/providers/irodori_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Irodori-TTS (audio.cpp) settings: model download UI, guidance-scale
/// sliders and inference-step count. Mirrors the structure of
/// [PiperSettingsSection] (design D9). Owns no state itself — all state
/// lives in the providers it watches, so the settings dialog shell stays
/// free of Irodori-specific controllers.
class IrodoriSettingsSection extends ConsumerWidget {
  const IrodoriSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IrodoriModelDownloadSection(),
        SizedBox(height: 16),
        Divider(),
        SizedBox(height: 8),
        _IrodoriSynthesisParams(),
      ],
    );
  }
}

class _IrodoriModelDownloadSection extends ConsumerWidget {
  const _IrodoriModelDownloadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final downloadState = ref.watch(irodoriModelDownloadProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: switch (downloadState) {
        IrodoriModelDownloadIdle() => ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: Text(l10n.settings_modelDataDownload),
            onPressed: () {
              ref.read(irodoriModelDownloadProvider.notifier).startDownload();
            },
          ),
        IrodoriModelDownloadDownloading(:final currentFile, :final progress) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(currentFile),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              if (progress != null)
                Text('${(progress * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  ref
                      .read(irodoriModelDownloadProvider.notifier)
                      .cancelDownload();
                },
                child: Text(l10n.common_cancelButton),
              ),
            ],
          ),
        IrodoriModelDownloadCompleted(:final modelsDir) => Row(
            children: [
              Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.settings_irodoriDownloaded}${modelsDir != null ? '\n$modelsDir' : ''}',
                ),
              ),
            ],
          ),
        IrodoriModelDownloadError(:final message) => Column(
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
                      .read(irodoriModelDownloadProvider.notifier)
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

class _IrodoriSynthesisParams extends ConsumerWidget {
  const _IrodoriSynthesisParams();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final speakerGuidanceScale = ref.watch(irodoriSpeakerGuidanceScaleProvider);
    final captionGuidanceScale = ref.watch(irodoriCaptionGuidanceScaleProvider);
    final numInferenceSteps = ref.watch(irodoriNumInferenceStepsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.settings_irodoriSpeakerGuidanceScale}: ${speakerGuidanceScale.toStringAsFixed(1)}',
          ),
          Slider(
            value: speakerGuidanceScale,
            min: 0.0,
            max: 10.0,
            divisions: 100,
            label: speakerGuidanceScale.toStringAsFixed(1),
            onChanged: (value) {
              ref
                  .read(irodoriSpeakerGuidanceScaleProvider.notifier)
                  .setValue(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.settings_irodoriCaptionGuidanceScale}: ${captionGuidanceScale.toStringAsFixed(1)}',
          ),
          Slider(
            value: captionGuidanceScale,
            min: 0.0,
            max: 10.0,
            divisions: 100,
            label: captionGuidanceScale.toStringAsFixed(1),
            onChanged: (value) {
              ref
                  .read(irodoriCaptionGuidanceScaleProvider.notifier)
                  .setValue(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.settings_irodoriNumInferenceSteps}: $numInferenceSteps',
          ),
          Slider(
            value: numInferenceSteps.toDouble(),
            min: 10.0,
            max: 80.0,
            divisions: 70,
            label: '$numInferenceSteps',
            onChanged: (value) {
              ref
                  .read(irodoriNumInferenceStepsProvider.notifier)
                  .setValue(value.round());
            },
          ),
        ],
      ),
    );
  }
}
