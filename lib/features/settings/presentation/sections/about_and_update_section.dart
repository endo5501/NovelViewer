import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/app_update/domain/distribution_type.dart';
import 'package:novel_viewer/features/app_update/domain/update_check_service.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class AboutAndUpdateSection extends ConsumerStatefulWidget {
  const AboutAndUpdateSection({super.key});

  @override
  ConsumerState<AboutAndUpdateSection> createState() =>
      _AboutAndUpdateSectionState();
}

class _AboutAndUpdateSectionState extends ConsumerState<AboutAndUpdateSection> {
  bool _checking = false;
  String? _resultMessage;
  late bool _autoCheck;

  @override
  void initState() {
    super.initState();
    _autoCheck = ref.read(updatePreferencesProvider).autoCheckEnabled;
  }

  String _normalizedTag(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _resultMessage = null;
    });
    final status =
        await ref.read(updateStatusProvider.notifier).check(manual: true);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _checking = false;
      _resultMessage = switch (status) {
        UpdateAvailable(:final release) => l10n
            .settings_updateAvailableMessage(_normalizedTag(release.tagName)),
        UpdateNotAvailable() => l10n.settings_upToDateMessage,
        UpdateCheckError() => l10n.settings_checkFailedMessage,
        UpdateSkipped() => null,
      };
    });
  }

  Future<void> _toggleAuto(bool value) async {
    await ref.read(updatePreferencesProvider).setAutoCheckEnabled(value);
    if (!mounted) return;
    setState(() => _autoCheck = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(packageInfoProvider);
    final distribution = ref.watch(distributionTypeProvider);
    final lastCheck = ref.watch(updatePreferencesProvider).lastCheckAt;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(l10n.settings_currentVersionLabel, info.version),
          _row(l10n.settings_buildNumberLabel, info.buildNumber),
          _row(
            l10n.settings_distributionLabel,
            distribution == DistributionType.installer
                ? l10n.settings_distributionInstaller
                : l10n.settings_distributionPortable,
          ),
          _row(
            l10n.settings_lastCheckedLabel,
            lastCheck?.toLocal().toString() ?? l10n.settings_lastCheckedNever,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: _checking ? null : _check,
                child: Text(l10n.settings_checkForUpdatesButton),
              ),
              const SizedBox(width: 12),
              if (_checking)
                Text(l10n.settings_checkingMessage)
              else if (_resultMessage != null)
                Flexible(child: Text(_resultMessage!)),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settings_autoCheckLabel),
            value: _autoCheck,
            onChanged: _toggleAuto,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
