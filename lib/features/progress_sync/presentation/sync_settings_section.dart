import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../data/oauth/progress_sync_auth.dart';
import '../data/progress_sync_service.dart';
import '../providers/progress_sync_settings_providers.dart';

/// Signing in to Google for progress sync, and how the sync is going.
class SyncSettingsSection extends ConsumerStatefulWidget {
  const SyncSettingsSection({super.key});

  @override
  ConsumerState<SyncSettingsSection> createState() =>
      _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends ConsumerState<SyncSettingsSection> {
  /// True while the consent screen is open in the browser.
  bool _signingIn = false;

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await ref.read(syncAccountActionsProvider).signIn();
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(syncAccountStateProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.syncSettings_title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(l10n.syncSettings_description),
          const SizedBox(height: 16),
          ...switch (account.status) {
            SyncAccountStatus.signedOut => _signedOut(l10n),
            SyncAccountStatus.signedIn => _signedIn(l10n, account.email!),
            SyncAccountStatus.needsReauth => _needsReauth(l10n, account.email!),
          },
        ],
      ),
    );
  }

  List<Widget> _signedOut(AppLocalizations l10n) => [
    FilledButton(
      onPressed: _signingIn ? null : _signIn,
      child: Text(l10n.syncSettings_signIn),
    ),
    if (_signingIn) ...[
      const SizedBox(height: 8),
      Text(l10n.syncSettings_signingIn),
    ],
  ];

  List<Widget> _needsReauth(AppLocalizations l10n, String email) => [
    Text(l10n.syncSettings_needsReauth(email)),
    const SizedBox(height: 8),
    FilledButton(
      onPressed: _signingIn ? null : _signIn,
      child: Text(l10n.syncSettings_signInAgain),
    ),
    if (_signingIn) ...[
      const SizedBox(height: 8),
      Text(l10n.syncSettings_signingIn),
    ],
  ];

  List<Widget> _signedIn(AppLocalizations l10n, String email) {
    final status = ref.watch(syncRunStatusProvider);
    final actions = ref.read(syncAccountActionsProvider);
    return [
      Text(l10n.syncSettings_signedInAs(email)),
      const SizedBox(height: 8),
      Text(_lastSynced(l10n, status)),
      if (status.lastError case final error?) ...[
        const SizedBox(height: 8),
        Text(
          l10n.syncSettings_lastError(error),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: status.running ? null : actions.syncNow,
            child: Text(
              status.running
                  ? l10n.syncSettings_syncing
                  : l10n.syncSettings_syncNow,
            ),
          ),
          OutlinedButton(
            onPressed: actions.signOut,
            child: Text(l10n.syncSettings_signOut),
          ),
        ],
      ),
    ];
  }

  String _lastSynced(AppLocalizations l10n, SyncRunStatus status) {
    final at = status.lastSuccessAt;
    if (at == null) return l10n.syncSettings_neverSynced;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return l10n.syncSettings_lastSynced(
      DateFormat.yMd(locale).add_Hm().format(at.toLocal()),
    );
  }
}
