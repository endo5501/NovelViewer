import 'package:flutter/material.dart';
import 'package:novel_viewer/features/file_browser/domain/move_destination.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Dialog that lists library-internal folders as move destinations. Tapping a
/// row pops the dialog with that destination's absolute path; cancelling pops
/// with null. Only library-internal organizational folders (and the library
/// root) are shown, so a move can never target outside the library.
class MoveDestinationDialog extends StatelessWidget {
  final List<MoveDestination> destinations;

  const MoveDestinationDialog({super.key, required this.destinations});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.fileBrowser_moveDialogTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final dest in destinations)
              Padding(
                padding: EdgeInsets.only(left: 16.0 * dest.depth),
                child: ListTile(
                  leading: Icon(
                    dest.depth == 0 ? Icons.home : Icons.folder,
                  ),
                  title: Text(
                    dest.depth == 0
                        ? l10n.fileBrowser_moveLibraryRoot
                        : dest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(dest.path),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancelButton),
        ),
      ],
    );
  }
}
