import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/app_update/presentation/update_dialog.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// AppBar action that appears only when a (non-snoozed) update is available.
class UpdateBadge extends ConsumerWidget {
  const UpdateBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(updateAvailableProvider);
    if (available == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      key: const Key('update_badge_button'),
      icon: const Badge(
        smallSize: 8,
        child: Icon(Icons.system_update_alt),
      ),
      tooltip: l10n.update_badgeTooltip,
      onPressed: () => UpdateDialog.show(context, available.release),
    );
  }
}
