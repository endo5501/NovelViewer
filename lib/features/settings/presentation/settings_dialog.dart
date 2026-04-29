import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/presentation/sections/general_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/llm_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/piper_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/qwen3_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/voice_reference_section.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.settings_title),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.settings_generalTabLabel),
                Tab(text: l10n.settings_ttsTabLabel),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _GeneralTab(),
                  _TtsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_closeButton),
        ),
      ],
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeneralSettingsSection(),
          Divider(),
          LlmSettingsSection(),
        ],
      ),
    );
  }
}

class _TtsTab extends ConsumerWidget {
  const _TtsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineType = ref.watch(ttsEngineTypeProvider);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const _EngineSelector(),
          const SizedBox(height: 16),
          if (engineType == TtsEngineType.qwen3) ...[
            const Qwen3SettingsSection(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: VoiceReferenceSection(),
            ),
          ],
          if (engineType == TtsEngineType.piper) const PiperSettingsSection(),
        ],
      ),
    );
  }
}

class _EngineSelector extends ConsumerWidget {
  const _EngineSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final engineType = ref.watch(ttsEngineTypeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_ttsEngine,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TtsEngineType>(
              segments: TtsEngineType.values
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
