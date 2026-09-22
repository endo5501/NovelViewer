/// Matches everything a ruby annotation contributes beyond its base: the
/// reading, the `rp` fallback parentheses, and the outer tags.
final _rubyTagPattern = RegExp(
  r'<rt>.*?</rt>|<rp>.*?</rp>|<ruby>|</ruby>',
  caseSensitive: false,
);

/// Returns [text] with ruby annotations reduced to their base text.
///
/// The stored novel text keeps ruby as HTML (`<ruby>紅蓮<rt>ぐれん</rt></ruby>`),
/// so the base of an annotated word is separated from the text around it by
/// tags. Anything that compares a word the reader can see against the source
/// has to strip those first, for two reasons that pull in the same direction:
/// a word matching the reading rather than the base would be a false positive,
/// and a word whose displayed form spans a tag boundary — `紅蓮の剣` written as
/// `<ruby>紅蓮<rt>ぐれん</rt></ruby>の剣` — is not a contiguous run of the raw
/// text at all, and would be missed.
///
/// Offsets into the result are offsets into the base text, which is the
/// coordinate space the viewer lays out; they do not map back onto [text].
String stripRubyAnnotations(String text) =>
    text.replaceAll(_rubyTagPattern, '');
