import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/text_content_renderer.dart';
import 'package:novel_viewer/features/text_viewer/presentation/widgets/tts_controls_bar.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Shell that lays out the text viewer: file content rendering on top,
/// TTS controls bar overlaid in the bottom-right. Owns no scroll, controller,
/// or rendering state — those live inside `TextContentRenderer` and
/// `TtsControlsBar` respectively.
class TextViewerPanel extends ConsumerWidget {
  const TextViewerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(fileContentProvider);

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          AppLocalizations.of(context)!.common_errorPrefix(error.toString()),
        ),
      ),
      data: (content) {
        if (content == null) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.textViewer_selectFilePrompt,
            ),
          );
        }
        return Stack(
          children: [
            TextContentRenderer(content: content),
            Positioned(
              right: 8,
              bottom: 8,
              child: TtsControlsBar(content: content),
            ),
          ],
        );
      },
    );
  }
}
