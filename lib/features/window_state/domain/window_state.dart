import 'package:flutter/foundation.dart';

/// Persisted geometry of the main window.
///
/// [width]/[height] always describe the *non-maximized* window: while the
/// window is maximized the OS reports the maximized extent, which would destroy
/// the size the user restores to. [maximized] is therefore kept as a separate
/// flag rather than being folded into the size.
@immutable
class WindowState {
  const WindowState({
    this.width,
    this.height,
    this.maximized = false,
  });

  /// Nothing has ever been persisted (or what was persisted was unusable).
  static const WindowState empty = WindowState();

  final double? width;
  final double? height;
  final bool maximized;

  /// Both axes are present, so the size can be restored.
  bool get hasSize => width != null && height != null;

  WindowState copyWith({
    double? width,
    double? height,
    bool? maximized,
  }) {
    return WindowState(
      width: width ?? this.width,
      height: height ?? this.height,
      maximized: maximized ?? this.maximized,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WindowState &&
        other.width == width &&
        other.height == height &&
        other.maximized == maximized;
  }

  @override
  int get hashCode => Object.hash(width, height, maximized);

  @override
  String toString() =>
      'WindowState(width: $width, height: $height, maximized: $maximized)';
}
