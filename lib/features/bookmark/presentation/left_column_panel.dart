import 'package:flutter/material.dart';
import 'package:novel_viewer/features/bookmark/presentation/bookmark_list_panel.dart';
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ファイル'),
            Tab(text: 'ブックマーク'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              FileBrowserPanel(),
              BookmarkListPanel(),
            ],
          ),
        ),
      ],
    );
  }
}
