import 'package:flutter/material.dart';

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
      title: const Text('タイトル変更'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '新しいタイトル',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('変更'),
        ),
      ],
    );
  }
}
