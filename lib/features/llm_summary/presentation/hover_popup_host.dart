import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/presentation/analysis_runner.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_anchor.dart';
import 'package:novel_viewer/features/llm_summary/presentation/hover_popup_widget.dart';
import 'package:novel_viewer/features/llm_summary/providers/hover_popup_provider.dart';
import 'package:novel_viewer/features/settings/data/text_display_mode.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/shared/gestures/pointer_kinds.dart';

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

  /// Sits under [_entry] and watches for the touch that means "done reading".
  OverlayEntry? _dismissEntry;

  /// Identifies the popup so its bounds can be excluded from that touch.
  final GlobalKey _popupKey = GlobalKey();

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
    _dismissEntry?.remove();
    _dismissEntry = null;
  }

  /// Dismisses the popup when a pointer that cannot hover presses outside it.
  ///
  /// Only such a pointer: a mouse leaves the popup's `MouseRegion` and is
  /// dismissed by that, and a click that dismissed as well would take the
  /// popup down while the pointer was still inside it.
  ///
  /// The press is observed, never consumed, so whatever it landed on still
  /// receives it — including a marked word, which then opens its own summary.
  void _onPointerDownOutside(PointerDownEvent event) {
    if (!kNoSecondaryButtonPointerKinds.contains(event.kind)) return;
    final notifier = ref.read(hoverPopupProvider.notifier);
    // The re-analysis dropdown is a MenuAnchor. Its items sit in an overlay
    // above this one and do not stop a press from reaching it, so without
    // this the touch that picks an item would take down the popup the menu
    // belongs to.
    if (notifier.isChildMenuOpen) return;
    if (_popupBounds()?.contains(event.position) ?? true) return;
    notifier.hide();
  }

  /// The popup's global bounds, or null before it has been laid out. A null
  /// is read as "inside", so the press that opened the popup cannot also
  /// close it in the same frame.
  Rect? _popupBounds() {
    final box = _popupKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _insertEntry({
    required Offset position,
    required String folderPath,
    required String word,
    required int currentEpisode,
    required String? currentFileName,
    required int maxEpisodeInFolder,
    required String? maxEpisodeFileName,
    required TextDisplayMode mode,
  }) {
    _removeEntry();
    _dismissEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDownOutside,
        ),
      ),
    );
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
            key: _popupKey,
            folderPath: folderPath,
            word: word,
            currentEpisode: currentEpisode,
            currentFileName: currentFileName,
            maxEpisodeInFolder: maxEpisodeInFolder,
            maxEpisodeFileName: maxEpisodeFileName,
          ),
        );
      },
    );
    // The barrier goes in first so it sits under the popup: a press on the
    // popup itself is then excluded by bounds rather than by luck.
    Overlay.of(context, rootOverlay: true)
      ..insert(_dismissEntry!)
      ..insert(_entry!);
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
      final selectedFile = ref.read(selectedFileProvider);
      final currentEpisode = resolveUpperBoundForCurrent(
        directoryPath: directory,
        currentFile: selectedFile,
      );
      final maxEpisode = resolveUpperBoundForAll(directory);
      final maxFileName = resolveSourceFileForAll(directory);
      _insertEntry(
        position: next.position!,
        folderPath: directory,
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
