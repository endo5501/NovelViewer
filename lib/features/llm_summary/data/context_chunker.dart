class ContextChunker {
  static const _defaultMaxChunkSize = 4000;

  static List<List<String>> split(
    List<String> contexts, {
    int maxChunkSize = _defaultMaxChunkSize,
  }) {
    if (contexts.isEmpty) return [];

    final chunks = <List<String>>[];
    var currentChunk = <String>[];
    var currentSize = 0;

    for (final context in contexts) {
      final entrySize = context.length;

      if (currentChunk.isNotEmpty &&
          currentSize + entrySize > maxChunkSize) {
        chunks.add(currentChunk);
        currentChunk = <String>[];
        currentSize = 0;
      }

      currentChunk.add(context);
      currentSize += entrySize;
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }
}
