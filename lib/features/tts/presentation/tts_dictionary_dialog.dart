import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../data/tts_dictionary_repository.dart';

class TtsDictionaryDialog extends ConsumerStatefulWidget {
  const TtsDictionaryDialog({
    super.key,
    required this.repository,
  });

  final TtsDictionaryRepository repository;

  static Future<void> show(
    BuildContext context, {
    required TtsDictionaryRepository repository,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TtsDictionaryDialog(repository: repository),
    );
  }

  @override
  ConsumerState<TtsDictionaryDialog> createState() =>
      _TtsDictionaryDialogState();
}

class _TtsDictionaryDialogState extends ConsumerState<TtsDictionaryDialog> {
  List<TtsDictionaryEntry> _entries = [];
  bool _loading = true;

  final _surfaceController = TextEditingController();
  final _readingController = TextEditingController();
  String? _addError;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _surfaceController.dispose();
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final entries = await widget.repository.getAllEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _addEntry() async {
    final surface = _surfaceController.text.trim();
    final reading = _readingController.text.trim();

    if (surface.isEmpty || reading.isEmpty) {
      setState(() => _addError = AppLocalizations.of(context)!.ttsDictionary_bothFieldsRequired);
      return;
    }

    try {
      await widget.repository.addEntry(surface, reading);
      _surfaceController.clear();
      _readingController.clear();
      setState(() => _addError = null);
      await _loadEntries();
    } catch (e) {
      setState(() => _addError = AppLocalizations.of(context)!.ttsDictionary_duplicateEntry);
    }
  }

  Future<void> _deleteEntry(int id) async {
    await widget.repository.deleteEntry(id);
    await _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.ttsDictionary_title),
      content: SizedBox(
        width: 480,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAddRow(),
            if (_addError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _addError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(child: _buildEntryList()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.common_closeButton),
        ),
      ],
    );
  }

  Widget _buildAddRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _surfaceController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.ttsDictionary_surfaceLabel,
              hintText: AppLocalizations.of(context)!.ttsDictionary_surfaceHint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _addEntry(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _readingController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.ttsDictionary_readingLabel,
              hintText: AppLocalizations.of(context)!.ttsDictionary_readingHint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _addEntry(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _addEntry,
          icon: const Icon(Icons.add),
          tooltip: AppLocalizations.of(context)!.ttsDictionary_addTooltip,
        ),
      ],
    );
  }

  Widget _buildEntryList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.ttsDictionary_emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (context, idx) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return ListTile(
          dense: true,
          title: Text(entry.surface),
          subtitle: Text(entry.reading),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: AppLocalizations.of(context)!.ttsDictionary_deleteTooltip,
            onPressed: () => _deleteEntry(entry.id),
          ),
        );
      },
    );
  }
}
