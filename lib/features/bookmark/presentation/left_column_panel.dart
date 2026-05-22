import 'package:flutter/material.dart';
import 'package:novel_viewer/features/bookmark/presentation/bookmark_list_panel.dart';
import 'package:novel_viewer/features/llm_summary/presentation/llm_summary_history_panel.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';

class LeftColumnPanel extends StatefulWidget {
  const LeftColumnPanel({super.key});

  @override
  State<LeftColumnPanel> createState() => _LeftColumnPanelState();
}

class _LeftColumnPanelState extends State<LeftColumnPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: l10n.leftColumn_historyTab),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              FileBrowserPanel(),
              BookmarkListPanel(),
              LlmSummaryHistoryPanel(),
            ],
          ),
        ),
      ],
    );
  }
}
