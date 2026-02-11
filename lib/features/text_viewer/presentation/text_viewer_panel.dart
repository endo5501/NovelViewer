import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';

class TextViewerPanel extends ConsumerWidget {
  const TextViewerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(fileContentProvider);

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('エラー: $error')),
      data: (content) {
        if (content == null) {
          return const Center(
            child: Text('ファイルを選択してください'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
            onSelectionChanged: (selection, cause) {
              final selectedText =
                  selection.textInside(content);
              ref.read(selectedTextProvider.notifier).setText(
                    selectedText.isEmpty ? null : selectedText,
                  );
            },
          ),
        );
      },
    );
  }
}
