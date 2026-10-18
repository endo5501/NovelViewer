import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Chooses the TTS engine among the ones this platform runs.
class TtsEngineSelector extends ConsumerWidget {
  const TtsEngineSelector({super.key, required this.engines});

  /// The engines this platform runs, in display order.
  final List<TtsEngineType> engines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final engineType = ref.watch(ttsEngineTypeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings_ttsEngine,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TtsEngineType>(
              segments: engines
                  .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                  .toList(),
              selected: {engineType},
              onSelectionChanged: (selected) {
                ref
                    .read(ttsEngineTypeProvider.notifier)
                    .setEngineType(selected.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}
