import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/data/irodori_model_variant.dart';
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
        _IrodoriVariantSelector(),
        SizedBox(height: 8),
        _IrodoriModelDownloadSection(),
        _IrodoriLegacyAssetsNotice(),
        SizedBox(height: 16),
        Divider(),
        SizedBox(height: 8),
        _IrodoriSynthesisParams(),
      ],
    );
  }
}

/// v3 / v4 selection.
///
/// v4 is a caption-less alternative, not an upgrade: supplying a reference
/// voice and a caption together makes it append speech that is not in the
/// text. The caption itself is gated in
/// `TtsEngineConfig.captionFromMemo`, below the UI — this widget only
/// explains why the caption controls are inert, so a user who writes a memo
/// is not left wondering why it has no effect.
class _IrodoriVariantSelector extends ConsumerWidget {
  const _IrodoriVariantSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final variant = ref.watch(irodoriModelVariantProvider);
    // Switching mid-transfer is guarded in the notifier too, but stopping it
    // here keeps the user from starting something the app then has to undo.
    final downloading =
        ref.watch(irodoriModelDownloadProvider) is IrodoriModelDownloadDownloading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_irodoriModelVariant),
          const SizedBox(height: 4),
          DropdownButton<IrodoriModelVariant>(
            key: const Key('irodori_variant_dropdown'),
            value: variant,
            isExpanded: true,
            items: [
              for (final v in IrodoriModelVariant.values)
                DropdownMenuItem(value: v, child: Text(v.label)),
            ],
            onChanged: downloading
                ? null
                : (value) {
                    if (value == null) return;
                    ref
                        .read(irodoriModelVariantProvider.notifier)
                        .setValue(value);
                  },
          ),
          if (!variant.supportsCaption) ...[
            const SizedBox(height: 8),
            Text(
              l10n.settings_irodoriVariantV4NoCaption,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Offers to reclaim the pre-GGUF safetensors assets.
///
/// Detection and the byte total are shown by the app; the deletion itself
/// stays an explicit user action because 2.9 GB is not recoverable and the
/// files may still be used elsewhere (e.g. the audio.cpp CLI).
class _IrodoriLegacyAssetsNotice extends ConsumerWidget {
  const _IrodoriLegacyAssetsNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final legacy = ref.watch(irodoriLegacyAssetsProvider);
    // Keyed off presence, not size: a directory left empty by a partial
    // delete frees 0 bytes but must stay reachable for cleanup.
    if (!legacy.present) return const SizedBox.shrink();

    // Decimal GB, matching how the model sizes are quoted everywhere else
    // (the legacy assets total 2,904,288,926 bytes = 2.90 GB).
    final gb = (legacy.bytes / 1000000000).toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.settings_irodoriLegacyAssetsFound} ($gb GB)'),
          const SizedBox(height: 4),
          OutlinedButton(
            key: const Key('irodori_delete_legacy_assets'),
            onPressed: () => _confirmAndDelete(context, ref, l10n, gb),
            child: Text(l10n.settings_irodoriLegacyAssetsDelete),
          ),
        ],
      ),
    );
  }

  /// Deleting ~2.9 GB is not reversible, so a single mis-tap must not do it.
  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String gb,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('irodori_delete_legacy_confirm_dialog'),
        title: Text(l10n.settings_irodoriLegacyAssetsDelete),
        content: Text('${l10n.settings_irodoriLegacyAssetsConfirm} ($gb GB)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancelButton),
          ),
          TextButton(
            key: const Key('irodori_delete_legacy_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settings_irodoriLegacyAssetsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(irodoriModelDownloadProvider.notifier).deleteLegacyAssets();
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
    // The stored value is kept so switching back to v3 restores it; only the
    // control is disabled.
    final captionSupported =
        ref.watch(irodoriModelVariantProvider).supportsCaption;

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
          Opacity(
            opacity: captionSupported ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.settings_irodoriCaptionGuidanceScale}: ${captionGuidanceScale.toStringAsFixed(1)}',
                ),
                Slider(
                  key: const Key('irodori_caption_guidance_slider'),
                  value: captionGuidanceScale,
                  min: 0.0,
                  max: 10.0,
                  divisions: 100,
                  label: captionGuidanceScale.toStringAsFixed(1),
                  onChanged: captionSupported
                      ? (value) {
                          ref
                              .read(irodoriCaptionGuidanceScaleProvider.notifier)
                              .setValue(value);
                        }
                      : null,
                ),
              ],
            ),
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
