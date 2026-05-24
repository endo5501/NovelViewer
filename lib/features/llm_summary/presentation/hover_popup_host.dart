import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
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
///
/// Display mode changes trigger an automatic hide() on the popup notifier
/// so the state stays consistent: the position math is mode-specific, so a
/// popup whose position was computed for the previous mode's layout must
/// not linger after the mode switch.
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
    required String? currentFileName,
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
            currentFileName: currentFileName,
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
        // Position math is mode-specific, so any visible popup is now
        // anchored to coordinates that no longer make sense. Drop it.
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
      _insertEntry(
        position: next.position!,
        folder: folder,
        word: next.word!,
        currentFileName: selectedFile?.name,
        mode: ref.read(displayModeProvider),
      );
    });

    return widget.child;
  }
}
