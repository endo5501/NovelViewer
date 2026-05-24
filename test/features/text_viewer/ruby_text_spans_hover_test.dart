import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/mark_matcher.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';

const _baseStyle = TextStyle(fontSize: 14.0);

/// Collects every TextSpan in [span]'s tree (depth-first).
List<TextSpan> _collectTextSpans(InlineSpan span) {
  final out = <TextSpan>[];
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      out.add(s);
      final children = s.children;
      if (children != null) {
        for (final c in children) {
          walk(c);
        }
      }
    } else if (s is WidgetSpan) {
      // Ruby spans wrap a Column; we don't descend into widgets here because
      // hover handlers are attached at the TextSpan level.
    }
  }

  walk(span);
  return out;
}

bool _hasMarkDecoration(TextSpan span) =>
    span.style?.decoration == TextDecoration.underline;

void main() {
  group('buildRubyTextSpans hover callbacks', () {
    test('attaches onEnter/onExit to marked spans with their word', () {
      final segments = [const PlainTextSegment('AAA アリス BBB')];
      final enters = <(String, Offset)>[];
      final exitTokens = <({int start, int end})>[];

      final result = buildRubyTextSpans(
        segments,
        _baseStyle,
        null,
        markedWords: {'アリス': MarkStyle.solid},
        onMarkEnter: (word, position, _) => enters.add((word, position)),
        onMarkExit: exitTokens.add,
      );

      final marked =
          _collectTextSpans(result).where(_hasMarkDecoration).toList();
      expect(marked, isNotEmpty,
          reason: 'A marked span should be produced for "アリス"');

      for (final span in marked) {
        expect(span.onEnter, isNotNull,
            reason: 'Marked span must have onEnter wired');
        expect(span.onExit, isNotNull,
            reason: 'Marked span must have onExit wired');
        expect(span.mouseCursor, isNot(MouseCursor.defer),
            reason: 'Marked span should advertise a hover-friendly cursor');
      }

      // Fire the handlers and verify they receive the right word.
      const pointerPosition = Offset(123, 456);
      for (final span in marked) {
        span.onEnter!(const PointerEnterEvent(position: pointerPosition));
        span.onExit!(const PointerExitEvent(position: pointerPosition));
      }
      expect(enters.map((e) => e.$1), everyElement('アリス'));
      expect(enters.first.$2, pointerPosition);
      expect(exitTokens, isNotEmpty,
          reason: 'Marked span exit should fire and deliver its token');
    });

    test('does not attach hover handlers to unmarked spans', () {
      final segments = [const PlainTextSegment('AAA アリス BBB')];

      final result = buildRubyTextSpans(
        segments,
        _baseStyle,
        null,
        markedWords: {'アリス': MarkStyle.solid},
        onMarkEnter: (_, _, _) {},
        onMarkExit: (_) {},
      );

      final unmarked =
          _collectTextSpans(result).where((s) => !_hasMarkDecoration(s)).toList();
      // Filter the synthetic outer parent TextSpan (no text, no marks).
      final unmarkedWithText =
          unmarked.where((s) => s.text != null && s.text!.isNotEmpty).toList();

      expect(unmarkedWithText, isNotEmpty);
      for (final span in unmarkedWithText) {
        expect(span.onEnter, isNull,
            reason: 'Unmarked text span must NOT have onEnter wired');
        expect(span.onExit, isNull,
            reason: 'Unmarked text span must NOT have onExit wired');
      }
    });

    test('attaches the correct word to each of multiple non-overlapping marks',
        () {
      final segments = [const PlainTextSegment('アリス と ボブ が会った')];
      final enters = <String>[];

      final result = buildRubyTextSpans(
        segments,
        _baseStyle,
        null,
        markedWords: {
          'アリス': MarkStyle.dotted,
          'ボブ': MarkStyle.solid,
        },
        onMarkEnter: (word, _, _) => enters.add(word),
        onMarkExit: (_) {},
      );

      final marked =
          _collectTextSpans(result).where(_hasMarkDecoration).toList();
      // Fire each marked span's onEnter and remember which word was reported.
      for (final span in marked) {
        span.onEnter!(const PointerEnterEvent());
      }

      expect(enters, containsAll(['アリス', 'ボブ']));
      expect(enters, hasLength(marked.length),
          reason: 'Every marked span should fire exactly once');
    });

    test('omits hover handlers entirely when callbacks are null', () {
      final segments = [const PlainTextSegment('アリス')];

      final result = buildRubyTextSpans(
        segments,
        _baseStyle,
        null,
        markedWords: {'アリス': MarkStyle.solid},
        // onMarkEnter / onMarkExit deliberately omitted
      );

      final marked =
          _collectTextSpans(result).where(_hasMarkDecoration).toList();
      expect(marked, isNotEmpty);
      for (final span in marked) {
        expect(span.onEnter, isNull,
            reason: 'No onEnter when callback is not supplied');
        expect(span.onExit, isNull,
            reason: 'No onExit when callback is not supplied');
      }
    });
  });
}
