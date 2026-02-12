sealed class TextSegment {
  const TextSegment();
}

class PlainTextSegment extends TextSegment {
  const PlainTextSegment(this.text);
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlainTextSegment && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'PlainTextSegment("$text")';
}

class RubyTextSegment extends TextSegment {
  const RubyTextSegment({required this.base, required this.rubyText});
  final String base;
  final String rubyText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RubyTextSegment &&
          base == other.base &&
          rubyText == other.rubyText;

  @override
  int get hashCode => Object.hash(base, rubyText);

  @override
  String toString() => 'RubyTextSegment(base: "$base", ruby: "$rubyText")';
}
