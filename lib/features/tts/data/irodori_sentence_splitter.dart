/// The commas a long sentence may be cut after.
const _commas = {'、', '，', ',', '；', ';'};

/// The longest piece, in characters, that Irodori-TTS on speech.cpp is asked
/// to speak in one request.
///
/// v4.1 Small MF can slur or garble a few words in the middle of a long
/// sentence: speech.cpp's documentation places the start at about 100
/// characters (18 s of speech), and our ASR read-back skipped words in a
/// 125-character sentence on the iPad. Irodori-TTS-Server cuts every input of
/// 80 characters or more at its punctuation, which is where this starts; it is
/// to be settled by listening on the device.
const irodoriMaxPieceLength = 80;

/// Cuts [text] after its commas into pieces of at most [maxLength] characters
/// where the commas allow, keeping every character, so that the pieces join
/// back into [text].
///
/// Each cut is the last comma within [maxLength]; where there is none, the
/// first comma after it, so a piece passes [maxLength] by no more than the run
/// up to one comma. A rest without a comma stays whole: a cut inside a word
/// would read wrongly, and the engine refuses a piece too long to speak.
List<String> splitAtCommas(
  String text, {
  int maxLength = irodoriMaxPieceLength,
}) {
  final pieces = <String>[];
  var rest = text;
  while (rest.length > maxLength) {
    final cut = _cutPosition(rest, maxLength);
    if (cut == null) break;
    pieces.add(rest.substring(0, cut));
    rest = rest.substring(cut);
  }
  if (rest.isNotEmpty) pieces.add(rest);
  return pieces;
}

/// Where to cut [text]: just after a comma, never at its end.
int? _cutPosition(String text, int maxLength) {
  int? within;
  for (var i = 0; i < text.length - 1; i++) {
    if (!_commas.contains(text[i])) continue;
    final cut = i + 1;
    if (cut <= maxLength) {
      within = cut;
    } else {
      return within ?? cut;
    }
  }
  return within;
}
