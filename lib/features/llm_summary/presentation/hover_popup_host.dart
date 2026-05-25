import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_anchor.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

/// Host widget that places its [child] into the tree while listening to
/// [hoverPopupProvider]. When the state becomes visible (and a novel
/// directory is open), it inserts a [HoverPopupWidget] into the nearest
/// [Overlay] near the pointer position. When the state goes hidden — or
/// the display mode changes — it removes the entry.
class HoverPopupHost extends ConsumerStatefulWidget {
  const HoverPopupHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HoverPopupHost> createState() => _HoverPopupHostState();
}

class _HoverPopupHostState extends ConsumerState<HoverPopupHost> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _insertEntry({
    required Offset position,
    required String folder,
    required String word,
    required int currentEpisode,
    required String? currentFileName,
    required int maxEpisodeInFolder,
    required String? maxEpisodeFileName,
    required TextDisplayMode mode,
  }) {
    _removeEntry();
    _entry = OverlayEntry(
      builder: (overlayContext) {
        final screen = MediaQuery.sizeOf(overlayContext);
        final anchor = computePopupAnchor(
          mode: mode,
          pointer: position,
          screenSize: screen,
        );
        return Positioned(
          left: anchor.left,
          top: anchor.top,
          child: HoverPopupWidget(
            folder: folder,
            word: word,
            currentEpisode: currentEpisode,
            currentFileName: currentFileName,
            maxEpisodeInFolder: maxEpisodeInFolder,
            maxEpisodeFileName: maxEpisodeFileName,
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TextDisplayMode>(displayModeProvider, (prev, next) {
      if (prev != next) {
        ref.read(hoverPopupProvider.notifier).hide();
      }
    });

    ref.listen<HoverPopupState>(hoverPopupProvider, (_, next) {
      if (!next.isVisible) {
        _removeEntry();
        return;
      }
      final directory = ref.read(currentDirectoryProvider);
      if (directory == null) {
        _removeEntry();
        return;
      }
      final folder = p.basename(directory);
      final selectedFile = ref.read(selectedFileProvider);
      final currentEpisode = resolveUpperBoundForCurrent(
        directoryPath: directory,
        currentFile: selectedFile,
      );
      final maxEpisode = resolveUpperBoundForAll(directory);
      final maxFileName = resolveSourceFileForAll(directory);
      _insertEntry(
        position: next.position!,
        folder: folder,
        word: next.word!,
        currentEpisode: currentEpisode,
        currentFileName: selectedFile?.name,
        maxEpisodeInFolder: maxEpisode,
        maxEpisodeFileName: maxFileName,
        mode: ref.read(displayModeProvider),
      );
    });

    return widget.child;
  }
}
