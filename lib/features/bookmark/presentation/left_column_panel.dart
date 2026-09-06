import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/bookmark/presentation/bookmark_list_panel.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_panel.dart';
import 'package:novel_viewer/features/llm_summary/providers/llm_summary_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';

class LeftColumnPanel extends ConsumerStatefulWidget {
  const LeftColumnPanel({super.key});

  @override
  ConsumerState<LeftColumnPanel> createState() => _LeftColumnPanelState();
}

class _LeftColumnPanelState extends ConsumerState<LeftColumnPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Whether the analysis history tab is part of this panel.
  ///
  /// Where summaries cannot be produced the tab could only ever list nothing,
  /// so it is absent rather than empty. Read once: a `TabController`'s length
  /// is fixed at construction, and the platform does not change while the app
  /// runs. A test selects the other case by overriding the provider before the
  /// widget is built.
  late final bool _hasHistoryTab;

  @override
  void initState() {
    super.initState();
    _hasHistoryTab = ref.read(llmSummarySupportedProvider);
    _tabController = TabController(length: _hasHistoryTab ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.leftColumn_filesTab),
            Tab(text: l10n.leftColumn_bookmarksTab),
            if (_hasHistoryTab) Tab(text: l10n.leftColumn_historyTab),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const FileBrowserPanel(),
              const BookmarkListPanel(),
              if (_hasHistoryTab) const LlmSummaryHistoryPanel(),
            ],
          ),
        ),
      ],
    );
  }
}
