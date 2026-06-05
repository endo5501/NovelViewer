import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/utils/file_name_utils.dart';

/// Dialog that prompts for a new organizational folder name. Returns the
/// entered name on confirmation, or null on cancel. The confirm button stays
/// disabled until the name is a valid folder name.
class NewFolderDialog extends StatefulWidget {
  /// When provided, prefills the field and is used as the rename title; lets
  /// the same dialog serve both "new folder" and "rename folder" flows.
  final String? initialName;
  final String title;

  /// Overrides the confirm button label. Defaults to the "create" label so the
  /// same dialog can serve the rename flow with a different action label.
  final String? confirmLabel;

  const NewFolderDialog({
    super.key,
    this.initialName,
    required this.title,
    this.confirmLabel,
  });

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
  late final TextEditingController _controller;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _isValid = isValidFolderName(_controller.text);
    _controller.addListener(_updateValidation);
  }

  void _updateValidation() {
    final newIsValid = isValidFolderName(_controller.text);
    if (newIsValid != _isValid) {
      setState(() => _isValid = newIsValid);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateValidation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.fileBrowser_folderNameLabel,
        ),
        onSubmitted: _isValid
            ? (_) => Navigator.of(context).pop(_controller.text.trim())
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancelButton),
        ),
        TextButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(widget.confirmLabel ?? l10n.fileBrowser_createButton),
        ),
      ],
    );
  }
}
