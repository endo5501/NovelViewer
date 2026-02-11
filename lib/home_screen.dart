import 'package:flutter/material.dart';
import 'package:novel_viewer/features/file_browser/presentation/file_browser_panel.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/shared/widgets/search_summary_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NovelViewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => SettingsDialog.show(context),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: FileBrowserPanel(key: const Key('left_column')),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: TextViewerPanel(key: const Key('center_column')),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 300,
            child: SearchSummaryPanel(key: const Key('right_column')),
          ),
        ],
      ),
    );
  }
}
