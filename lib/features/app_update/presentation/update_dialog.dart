import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/app_update/data/installer_updater.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:novel_viewer/features/app_update/domain/distribution_type.dart';
import 'package:novel_viewer/features/app_update/domain/update_constants.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.release});

  final ReleaseInfo release;

  static Future<void> show(BuildContext context, ReleaseInfo release) {
    return showDialog(
      context: context,
      // Non-dismissable so a tap outside cannot abandon an in-progress
      // download; the dialog is closed via its own buttons.
      barrierDismissible: false,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  String _normalizedTag(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  Future<void> _startUpdate() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _downloading = true;
      _progress = null;
      _error = null;
    });

    final updater = ref.read(installerUpdaterProvider);
    final result = await updater.apply(
      widget.release,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    switch (result.outcome) {
      case UpdateOutcome.launched:
        // Process is exiting; nothing more to do.
        break;
      case UpdateOutcome.checksumMismatch:
        setState(() {
          _downloading = false;
          _error = l10n.update_failedChecksumMessage;
        });
      case UpdateOutcome.missingAsset:
        setState(() {
          _downloading = false;
          _error = l10n.update_missingAssetMessage;
        });
      case UpdateOutcome.downloadFailed:
      case UpdateOutcome.launchFailed:
        setState(() {
          _downloading = false;
          _error = l10n.update_failedMessage;
        });
    }
  }

  Future<void> _openReleasePage() async {
    try {
      await launchUrl(
        Uri.parse(releasePageUrl(widget.release.tagName)),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Even if no browser handler is available, close the dialog rather than
      // leaving it stuck open on an unhandled exception.
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _later() {
    ref.read(updateStatusProvider.notifier).snooze();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentVersion = ref.watch(packageInfoProvider).version;
    final isInstaller =
        ref.watch(distributionTypeProvider) == DistributionType.installer;
    final notes = widget.release.body.trim();

    return AlertDialog(
      title: Text(l10n.update_dialogTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.update_versionTransition(
                currentVersion,
                _normalizedTag(widget.release.tagName),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.update_releaseNotesLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(
                  notes.isEmpty ? l10n.update_noReleaseNotes : notes,
                ),
              ),
            ),
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 4),
              Text(l10n.update_downloadingLabel),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: _buildActions(l10n, isInstaller),
    );
  }

  List<Widget> _buildActions(AppLocalizations l10n, bool isInstaller) {
    if (_downloading) {
      return const [];
    }

    final later = TextButton(
      onPressed: _later,
      child: Text(l10n.update_laterButton),
    );
    final openPage = TextButton(
      onPressed: _openReleasePage,
      child: Text(l10n.update_openReleasePageButton),
    );

    if (!isInstaller) {
      // Portable / ZIP: notify-and-link only, no in-app download.
      return [later, openPage];
    }

    final primaryLabel =
        _error == null ? l10n.update_updateButton : l10n.update_retryButton;
    return [
      later,
      openPage,
      FilledButton(
        onPressed: _startUpdate,
        child: Text(primaryLabel),
      ),
    ];
  }
}
