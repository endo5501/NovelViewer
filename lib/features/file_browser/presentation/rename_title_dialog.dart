import 'package:flutter/material.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

class RenameTitleDialog extends StatefulWidget {
  final String currentTitle;

  const RenameTitleDialog({super.key, required this.currentTitle});

  @override
  State<RenameTitleDialog> createState() => _RenameTitleDialogState();
}

class _RenameTitleDialogState extends State<RenameTitleDialog> {
  late final TextEditingController _controller;
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
    _isValid = widget.currentTitle.trim().isNotEmpty;
    _controller.addListener(_updateValidation);
  }

  void _updateValidation() {
    final newIsValid = _controller.text.trim().isNotEmpty;
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
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.renameTitle_title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.renameTitle_newTitleLabel,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.common_cancelButton),
        ),
        TextButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(AppLocalizations.of(context)!.renameTitle_changeButton),
        ),
      ],
    );
  }
}
