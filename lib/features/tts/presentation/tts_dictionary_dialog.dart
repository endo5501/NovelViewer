import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      setState(() => _addError = '表記と読みの両方を入力してください');
      return;
    }

    try {
      await widget.repository.addEntry(surface, reading);
      _surfaceController.clear();
      _readingController.clear();
      setState(() => _addError = null);
      await _loadEntries();
    } catch (e) {
      setState(() => _addError = '同じ表記が既に登録されています');
    }
  }

  Future<void> _deleteEntry(int id) async {
    await widget.repository.deleteEntry(id);
    await _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('読み上げ辞書'),
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
          child: const Text('閉じる'),
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
            decoration: const InputDecoration(
              labelText: '表記',
              hintText: '山田太郎',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _addEntry(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _readingController,
            decoration: const InputDecoration(
              labelText: '読み',
              hintText: 'やまだたろう',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _addEntry(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _addEntry,
          icon: const Icon(Icons.add),
          tooltip: '追加',
        ),
      ],
    );
  }

  Widget _buildEntryList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          '辞書にエントリがありません\n上のフォームから追加してください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
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
            tooltip: '削除',
            onPressed: () => _deleteEntry(entry.id),
          ),
        );
      },
    );
  }
}
