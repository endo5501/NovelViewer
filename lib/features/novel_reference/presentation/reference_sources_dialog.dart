import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';
import 'package:novel_viewer/features/novel_reference/providers/novel_reference_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

final _log = Logger('novel_reference');

/// Edits which novels the novel [folderName] draws on as reference sources.
///
/// Edits stay local until "保存"; cancelling or dismissing leaves the stored
/// relations as they were. Alongside the editable direct sources the dialog
/// shows, read-only, what LLM analysis will actually read through them (the
/// ancestors, recomputed as the edit changes) and which novels would be
/// affected by editing this one (its children).
class ReferenceSourcesDialog extends ConsumerStatefulWidget {
  const ReferenceSourcesDialog({
    super.key,
    required this.folderName,
    required this.title,
  });

  final String folderName;
  final String title;

  @override
  ConsumerState<ReferenceSourcesDialog> createState() =>
      _ReferenceSourcesDialogState();
}

class _ReferenceSourcesDialogState
    extends ConsumerState<ReferenceSourcesDialog> {
  /// The direct sources being edited; null until the stored ones load.
  Set<String>? _parents;
  bool _saving = false;
  bool _saveFailed = false;

  /// The stored relations with this novel's own edges replaced by the edit.
  List<ReferenceRelation> _editedGraph(List<ReferenceRelation> stored) => [
    for (final r in stored)
      if (r.child != widget.folderName) r,
    for (final parent in _parents!)
      ReferenceRelation(child: widget.folderName, parent: parent),
  ];

  Future<void> _add(
    List<ReferenceRelation> graph,
    List<NovelMetadata> novels,
  ) async {
    final excluded = {
      widget.folderName,
      ...resolveDescendants(widget.folderName, graph),
      ..._parents!,
    };
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => ReferenceSourcePickerDialog(
        candidates: [
          for (final n in novels)
            if (!excluded.contains(n.folderName)) n,
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _parents = {..._parents!, picked};
      _saveFailed = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(novelReferenceRepositoryProvider)
          .replaceParents(widget.folderName, _parents!);
      ref.invalidate(novelReferenceRelationsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      _log.warning('saving reference sources failed', e, st);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final relationsAsync = ref.watch(novelReferenceRelationsProvider);
    final novelsAsync = ref.watch(allNovelsProvider);

    final Widget content;
    final relations = relationsAsync.value;
    final novels = novelsAsync.value;
    if (relations == null || novels == null) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      _parents ??= {
        for (final r in relations)
          if (r.child == widget.folderName) r.parent,
      };
      final byFolder = {for (final n in novels) n.folderName: n};
      String titleOf(String folder) => byFolder[folder]?.title ?? folder;
      final graph = _editedGraph(relations);
      final inherited = resolveAncestors(
        widget.folderName,
        graph,
      ).where((a) => !_parents!.contains(a.folderName)).toList();
      final children =
          relations
              .where((r) => r.parent == widget.folderName)
              .map((r) => r.child)
              .toList()
            ..sort((a, b) => titleOf(a).compareTo(titleOf(b)));
      final direct = _parents!.toList()
        ..sort((a, b) => titleOf(a).compareTo(titleOf(b)));

      content = ListView(
        shrinkWrap: true,
        children: [
          _Section(
            key: const Key('reference_sources_direct'),
            label: l10n.referenceSources_directSection,
            children: [
              for (final folder in direct)
                _NovelRow(
                  title: titleOf(folder),
                  isWeb: byFolder[folder]?.siteType == 'web',
                  trailing: IconButton(
                    key: Key('reference_source_remove_$folder'),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.referenceSources_removeTooltip,
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _parents = {..._parents!}..remove(folder);
                            _saveFailed = false;
                          }),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.referenceSources_addButton),
                  onPressed: _saving ? null : () => _add(graph, novels),
                ),
              ),
            ],
          ),
          _Section(
            key: const Key('reference_sources_inherited'),
            label: l10n.referenceSources_inheritedSection,
            children: [
              if (inherited.isEmpty) _NoneRow(text: l10n.referenceSources_none),
              for (final a in inherited)
                _NovelRow(
                  title: titleOf(a.folderName),
                  isWeb: byFolder[a.folderName]?.siteType == 'web',
                  subtitle: l10n.referenceSources_via(titleOf(a.via)),
                ),
            ],
          ),
          _Section(
            key: const Key('reference_sources_children'),
            label: l10n.referenceSources_childrenSection,
            children: [
              if (children.isEmpty) _NoneRow(text: l10n.referenceSources_none),
              for (final folder in children)
                _NovelRow(
                  title: titleOf(folder),
                  isWeb: byFolder[folder]?.siteType == 'web',
                ),
            ],
          ),
          if (_saveFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.referenceSources_saveFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.referenceSources_dialogTitle(widget.title)),
      content: SizedBox(width: double.maxFinite, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancelButton),
        ),
        TextButton(
          onPressed: _parents == null || _saving ? null : _save,
          child: Text(l10n.common_saveButton),
        ),
      ],
    );
  }
}

/// Lists registered novels to add as a reference source, narrowed by a title
/// search. The caller decides which novels are candidates; tapping one pops
/// the dialog with its folder name.
class ReferenceSourcePickerDialog extends StatefulWidget {
  const ReferenceSourcePickerDialog({super.key, required this.candidates});

  final List<NovelMetadata> candidates;

  @override
  State<ReferenceSourcePickerDialog> createState() =>
      _ReferenceSourcePickerDialogState();
}

class _ReferenceSourcePickerDialogState
    extends State<ReferenceSourcePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _query.trim().toLowerCase();
    final shown =
        widget.candidates
            .where((n) => query.isEmpty || n.title.toLowerCase().contains(query))
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    return AlertDialog(
      title: Text(l10n.referenceSources_pickerTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('reference_source_picker_search'),
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.referenceSources_searchHint,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: shown.isEmpty
                  ? _NoneRow(text: l10n.referenceSources_noCandidates)
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final n in shown)
                          _NovelRow(
                            title: n.title,
                            isWeb: n.siteType == 'web',
                            onTap: () => Navigator.of(context).pop(n.folderName),
                          ),
                      ],
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

class _Section extends StatelessWidget {
  const _Section({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _NovelRow extends StatelessWidget {
  const _NovelRow({
    required this.title,
    required this.isWeb,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final bool isWeb;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lines = [?subtitle, if (isWeb) l10n.referenceSources_webCollection];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(isWeb ? Icons.public : Icons.menu_book),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: lines.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [for (final line in lines) Text(line)],
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _NoneRow extends StatelessWidget {
  const _NoneRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
