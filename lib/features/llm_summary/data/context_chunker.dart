class ContextChunker {
  static const _defaultMaxChunkSize = 4000;

  /// Packs [contexts] into chunks of at most [maxChunkSize] characters.
  ///
  /// [separator] is what the caller will put between the entries of a chunk
  /// when it joins them, and it counts toward the size. Left empty, only the
  /// entries count, so a chunk joined with a separator can run past the
  /// size by the separators' length.
  static List<List<String>> split(
    List<String> contexts, {
    int maxChunkSize = _defaultMaxChunkSize,
    String separator = '',
  }) {
    if (contexts.isEmpty) return [];

    final chunks = <List<String>>[];
    var currentChunk = <String>[];
    var currentSize = 0;

    for (final context in _withinLimit(contexts, maxChunkSize)) {
      final entrySize = context.length;
      final joinedSize = currentChunk.isEmpty
          ? entrySize
          : currentSize + separator.length + entrySize;

      if (currentChunk.isNotEmpty && joinedSize > maxChunkSize) {
        chunks.add(currentChunk);
        currentChunk = <String>[context];
        currentSize = entrySize;
        continue;
      }

      currentChunk.add(context);
      currentSize = joinedSize;
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  /// The same entries, with any that alone exceed [maxChunkSize] broken up.
  ///
  /// An entry is normally kept whole: it is a passage around a match, and
  /// cutting it costs the model the run-up to what it is being asked about.
  /// But an entry larger than the whole budget cannot be kept whole without
  /// handing the model more than it accepts, which on a model with a small
  /// window fails the request outright. A novel written in long paragraphs
  /// produces such entries. Cutting one is worse than not having to; it is
  /// better than losing the passage entirely.
  static Iterable<String> _withinLimit(
    List<String> contexts,
    int maxChunkSize,
  ) sync* {
    for (final context in contexts) {
      if (context.length <= maxChunkSize) {
        yield context;
        continue;
      }
      var rest = context;
      while (rest.length > maxChunkSize) {
        // Prefer a line break, so a cut lands between lines where it can.
        var cut = rest.lastIndexOf('\n', maxChunkSize);
        if (cut <= 0) cut = maxChunkSize;
        yield rest.substring(0, cut);
        rest = rest.substring(cut);
      }
      if (rest.isNotEmpty) yield rest;
    }
  }
}
