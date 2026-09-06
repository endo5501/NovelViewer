import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/settings/presentation/sections/about_and_update_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/general_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/irodori_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/llm_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/piper_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/qwen3_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/voice_reference_section.dart';
import 'package:novel_viewer/features/keyboard_shortcuts/presentation/shortcut_settings_section.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/providers/tts_availability_provider.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(context: context, builder: (_) => const SettingsDialog());
  }

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog>
    with SingleTickerProviderStateMixin {
  /// Read once: the platform does not change mid-session, and the tab count
  /// has to be fixed before the controller exists.
  late final bool _ttsSupported = ref.read(ttsSupportedProvider);

  late final TabController _tabController = TabController(
    length: _ttsSupported ? 3 : 2,
    vsync: this,
  );

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
                // Withheld where TTS cannot run: this tab reaches the native
                // engine, the microphone, and a desktop-only drop target.
                if (_ttsSupported) Tab(text: l10n.settings_ttsTabLabel),
                Tab(text: l10n.settings_aboutUpdateTab),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const _GeneralTab(),
                  if (_ttsSupported) const _TtsTab(),
                  const SingleChildScrollView(child: AboutAndUpdateSection()),
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

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Withheld where the LLM cannot be reached: the endpoint this section
    // configures is plaintext HTTP, which the platform blocks.
    final llmSupported = ref.watch(llmSummarySupportedProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GeneralSettingsSection(),
          const Divider(),
          const ShortcutSettingsSection(),
          if (llmSupported) ...[const Divider(), const LlmSettingsSection()],
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
          if (engineType == TtsEngineType.irodori) ...[
            const IrodoriSettingsSection(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: VoiceReferenceSection(),
            ),
          ],
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
          Text(
            l10n.settings_ttsEngine,
            style: Theme.of(context).textTheme.titleSmall,
          ),
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
