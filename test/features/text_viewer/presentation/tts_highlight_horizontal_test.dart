import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';
import 'package:novel_viewer/features/text_viewer/presentation/ruby_text_builder.dart';

void main() {
  group('buildRubyTextSpans - TTS highlight', () {
    test('applies green highlight to TTS range', () {
      final segments = [const PlainTextSegment('はじめの文。次の文。')];
      final span = buildRubyTextSpans(
        segments,
        const TextStyle(),
        null,
        ttsHighlightRange: const TextRange(start: 0, end: 6),
      );

      final children = span.children!.whereType<TextSpan>().toList();
      final highlighted = children
          .where((s) =>
              s.style?.backgroundColor != null &&
              s.style!.backgroundColor!.toARGB32() == Colors.green.withValues(alpha: 0.3).toARGB32())
          .toList();
      expect(highlighted, isNotEmpty);
      expect(highlighted.first.text, 'はじめの文。');
    });

    test('no TTS highlight when ttsHighlightRange is null', () {
      final segments = [const PlainTextSegment('テスト文。')];
      final span = buildRubyTextSpans(
        segments,
        const TextStyle(),
        null,
      );

      final children = span.children!.whereType<TextSpan>().toList();
      final highlighted = children
          .where((s) =>
              s.style?.backgroundColor != null &&
              s.style!.backgroundColor!.toARGB32() == Colors.green.withValues(alpha: 0.3).toARGB32())
          .toList();
      expect(highlighted, isEmpty);
    });

    test('TTS highlight applies to partial plain text segment', () {
      final segments = [const PlainTextSegment('あいうえおかきくけこ')];
      final span = buildRubyTextSpans(
        segments,
        const TextStyle(),
        null,
        ttsHighlightRange: const TextRange(start: 3, end: 7),
      );

      final children = span.children!.whereType<TextSpan>().toList();
      final highlighted = children
          .where((s) =>
              s.style?.backgroundColor != null &&
              s.style!.backgroundColor!.toARGB32() == Colors.green.withValues(alpha: 0.3).toARGB32())
          .toList();
      expect(highlighted, hasLength(1));
      expect(highlighted.first.text, 'えおかき');
    });

    test('search highlight takes priority over TTS highlight', () {
      final segments = [const PlainTextSegment('太郎が走った。')];
      // Both search and TTS highlighting active, search for '太郎'
      // TTS range covers whole text
      final span = buildRubyTextSpans(
        segments,
        const TextStyle(),
        '太郎',
        ttsHighlightRange: const TextRange(start: 0, end: 7),
      );

      final children = span.children!.whereType<TextSpan>().toList();
      // '太郎' should have yellow (search) highlight, not green
      final searchHighlighted = children
          .where((s) =>
              s.style?.backgroundColor != null &&
              s.style!.backgroundColor == Colors.yellow)
          .toList();
      expect(searchHighlighted, hasLength(1));
      expect(searchHighlighted.first.text, '太郎');
    });

    test('search highlight uses amber in dark mode with TTS active', () {
      final segments = [const PlainTextSegment('太郎が走った。')];
      final span = buildRubyTextSpans(
        segments,
        const TextStyle(),
        '太郎',
        ttsHighlightRange: const TextRange(start: 0, end: 7),
        brightness: Brightness.dark,
      );

      final children = span.children!.whereType<TextSpan>().toList();
      final searchHighlighted = children
          .where((s) =>
              s.style?.backgroundColor != null &&
              s.style!.backgroundColor == Colors.amber.shade700)
          .toList();
      expect(searchHighlighted, hasLength(1));
      expect(searchHighlighted.first.text, '太郎');
    });
  });
}
