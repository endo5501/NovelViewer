import 'package:flutter/foundation.dart' show immutable;

/// A text selection made in the viewer.
///
/// [plainTextOffset] is where the selection starts in *plain-text*
/// coordinates: the content with ruby markup replaced by its base text. That
/// is the space `TextSegment.offset`, `tts_segments.text_offset` and the TTS
/// highlight range all live in, so the offset can be compared against them
/// directly. It is deliberately NOT an offset into the raw file content
/// (which still carries `<ruby>` markup) and NOT a `SelectableText.rich`
/// display offset (where a ruby annotation counts as one character).
///
/// Carrying the offset is what lets TTS start playback at the selection:
/// recovering it afterwards by searching [text] in the raw content is not
/// possible, because ruby markup shifts every position and a short selection
/// can match an earlier occurrence.
///
/// This lives in the data layer rather than next to `selectedTextProvider` so
/// the viewer widgets can report a selection without depending on Riverpod.
@immutable
class ViewerSelection {
  const ViewerSelection({required this.text, required this.plainTextOffset});

  final String text;
  final int plainTextOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerSelection &&
          other.text == text &&
          other.plainTextOffset == plainTextOffset;

  @override
  int get hashCode => Object.hash(text, plainTextOffset);

  @override
  String toString() =>
      'ViewerSelection(text: $text, plainTextOffset: $plainTextOffset)';
}
