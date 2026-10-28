import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../data/tts_dictionary_repository.dart';

/// The narrowest add form that holds both fields, the "do not read aloud"
/// checkbox and the add button on one line with room left to read the
/// fields. The dialog is 480 wide on a desktop or an iPad, and at most about
/// 300 on a phone held upright.
const double _kSingleLineFormMinWidth = 400;

class TtsDictionaryDialog extends ConsumerStatefulWidget {
  const TtsDictionaryDialog({
    super.key,
    required this.repository,
    this.initialSurface,
  });

  final TtsDictionaryRepository repository;
  final String? initialSurface;

  static Future<void> show(
    BuildContext context, {
    required TtsDictionaryRepository repository,
    String? initialSurface,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TtsDictionaryDialog(
        repository: repository,
        initialSurface: initialSurface,
      ),
    );
  }

  @override
  ConsumerState<TtsDictionaryDialog> createState() =>
      _TtsDictionaryDialogState();
}

class _TtsDictionaryDialogState extends ConsumerState<TtsDictionaryDialog> {
  List<TtsDictionaryEntry> _entries = [];
  bool _loading = true;

  late final TextEditingController _surfaceController;
  final _readingController = TextEditingController();
  String? _addError;

  /// When set, the entry being added has no reading: the surface is dropped
  /// from the synthesis text instead of being replaced.
  bool _noReading = false;

  @override
  void initState() {
    super.initState();
    _surfaceController = TextEditingController(
      text: widget.initialSurface ?? '',
    );
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
    // Read from the checkbox rather than the field: the field keeps showing
    // whatever was typed before the box was ticked, and that text must not
    // reach the database.
    final reading = _noReading ? '' : _readingController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (surface.isEmpty) {
      setState(
        () => _addError = _noReading
            ? l10n.ttsDictionary_surfaceRequired
            : l10n.ttsDictionary_bothFieldsRequired,
      );
      return;
    }
    if (!_noReading && reading.isEmpty) {
      setState(() => _addError = l10n.ttsDictionary_bothFieldsRequired);
      return;
    }

    try {
      await widget.repository.addEntry(surface, reading);
      _surfaceController.clear();
      _readingController.clear();
      setState(() {
        _addError = null;
        _noReading = false;
      });
      await _loadEntries();
    } catch (e) {
      setState(
        () => _addError = AppLocalizations.of(
          context,
        )!.ttsDictionary_duplicateEntry,
      );
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final singleLine = constraints.maxWidth >= _kSingleLineFormMinWidth;
            final header = [
              _buildAddRow(singleLine: singleLine),
              if (_addError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _addError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ];
            if (singleLine) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...header,
                  Expanded(child: _buildEntryList()),
                ],
              );
            }
            // The stacked form is three lines tall, and with the keyboard up
            // a small phone leaves the dialog less height than that and the
            // list together, so there the form scrolls along with the list.
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: header,
                  ),
                ),
                if (_loading || _entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEntryList(),
                  )
                else
                  SliverList.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (context, idx) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _buildEntryTile(_entries[index]),
                  ),
              ],
            );
          },
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

  Widget _buildAddRow({required bool singleLine}) {
    final surfaceField = TextField(
      controller: _surfaceController,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.ttsDictionary_surfaceLabel,
        hintText: AppLocalizations.of(context)!.ttsDictionary_surfaceHint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _addEntry(),
    );
    final readingField = TextField(
      controller: _readingController,
      enabled: !_noReading,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.ttsDictionary_readingLabel,
        hintText: AppLocalizations.of(context)!.ttsDictionary_readingHint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _addEntry(),
    );
    // Ticking this stores an empty reading, which the substitution treats
    // as a deletion — for symbol runs like "――‐" that carry no sound.
    final noReading = Tooltip(
      message: AppLocalizations.of(context)!.ttsDictionary_noReadingLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: _noReading,
            onChanged: (value) => setState(() => _noReading = value ?? false),
          ),
          Text(
            AppLocalizations.of(context)!.ttsDictionary_noReadingLabel,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
    final addButton = IconButton.filled(
      onPressed: _addEntry,
      icon: const Icon(Icons.add),
      tooltip: AppLocalizations.of(context)!.ttsDictionary_addTooltip,
    );

    // The checkbox, its label and the button take about 200 of the form's
    // width whatever it is. A phone's dialog is not much wider than that, so
    // on one line the two fields shrank until nothing typed in them could be
    // read; there each field gets a line of its own.
    if (singleLine) {
      return Row(
        children: [
          Expanded(child: surfaceField),
          const SizedBox(width: 8),
          Expanded(child: readingField),
          const SizedBox(width: 8),
          noReading,
          const SizedBox(width: 8),
          addButton,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        surfaceField,
        const SizedBox(height: 8),
        readingField,
        const SizedBox(height: 8),
        Row(children: [noReading, const Spacer(), addButton]),
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
      itemBuilder: (context, index) => _buildEntryTile(_entries[index]),
    );
  }

  Widget _buildEntryTile(TtsDictionaryEntry entry) {
    final isNoReading = entry.reading.isEmpty;
    return ListTile(
      dense: true,
      title: Text(entry.surface),
      // An empty subtitle would read as a broken row rather than a
      // deliberate "not read aloud" entry.
      subtitle: Text(
        isNoReading
            ? AppLocalizations.of(context)!.ttsDictionary_noReadingDisplay
            : entry.reading,
        style: isNoReading
            ? TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
              )
            : null,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: AppLocalizations.of(context)!.ttsDictionary_deleteTooltip,
        onPressed: () => _deleteEntry(entry.id),
      ),
    );
  }
}
