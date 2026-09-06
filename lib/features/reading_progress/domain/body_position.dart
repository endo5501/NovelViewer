import 'package:flutter/widgets.dart' show Characters;
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/shared/utils/content_hash.dart';

/// Maps ruby WidgetSpan coordinates to layout-independent UTF-16 body offsets.
class BodyPositionMap {
  BodyPositionMap(this.segments);

  final List<TextSegment> segments;
  late final String text = segments
      .map(
        (segment) => switch (segment) {
          PlainTextSegment(:final text) => text,
          RubyTextSegment(:final base) => base,
        },
      )
      .join();
  late final String hash = computeContentHash(text);
  late final List<int> _boundaries = _characterBoundaries();

  List<int> _characterBoundaries() {
    final result = <int>[0];
    var offset = 0;
    for (final character in Characters(text)) {
      offset += character.length;
      result.add(offset);
    }
    return result;
  }

  int normalize(int offset) {
    var low = 0;
    var high = _boundaries.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_boundaries[mid] <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return _boundaries[low == 0 ? 0 : low - 1];
  }

  /// Clamps rather than snaps to a grapheme boundary: the vertical pagination
  /// splits on runes, so a page can legitimately start inside a cluster, and
  /// moving the anchor back before that page start makes the viewer resolve
  /// the previous page. Consumers that need a display position go through
  /// [toDisplayOffset], which normalizes on its own.
  int restore(int offset, String? savedHash) =>
      savedHash == hash ? offset.clamp(0, text.length) : 0;

  int fromDisplayOffset(int offset) {
    var display = 0;
    var body = 0;
    for (final segment in segments) {
      final length = switch (segment) {
        PlainTextSegment(:final text) => text.length,
        RubyTextSegment() => 1,
      };
      if (offset < display + length) {
        return normalize(
          body + (segment is RubyTextSegment ? 0 : offset - display),
        );
      }
      display += length;
      body += switch (segment) {
        PlainTextSegment(:final text) => text.length,
        RubyTextSegment(:final base) => base.length,
      };
    }
    return normalize(body);
  }

  int toDisplayOffset(int offset) {
    final target = normalize(offset);
    var body = 0;
    var display = 0;
    for (final segment in segments) {
      final length = switch (segment) {
        PlainTextSegment(:final text) => text.length,
        RubyTextSegment(:final base) => base.length,
      };
      if (target < body + length) {
        return display + (segment is RubyTextSegment ? 0 : target - body);
      }
      body += length;
      display += segment is RubyTextSegment ? 1 : length;
    }
    return display;
  }
}
