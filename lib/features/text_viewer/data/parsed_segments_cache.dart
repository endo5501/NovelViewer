import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

/// LRU cache of parsed `TextSegment` lists keyed by a content hash.
///
/// Lifetime is the application (via Riverpod provider). Multiple renderers
/// rendering the same content share the same parsed result without invoking
/// the parser again. Bounded by [maxEntries] to cap memory; least-recently-used
/// entries are evicted when the limit is exceeded.
class ParsedSegmentsCache {
  ParsedSegmentsCache({this.maxEntries = 50});

  final int maxEntries;
  // LinkedHashMap (Dart's default Map impl) preserves insertion order; we
  // re-insert on access to maintain LRU order.
  final Map<String, List<TextSegment>> _byHash = {};

  int get size => _byHash.length;

  List<TextSegment> getOrParse(
    String content,
    String hash,
    List<TextSegment> Function(String) parser,
  ) {
    final cached = _byHash.remove(hash);
    if (cached != null) {
      _byHash[hash] = cached;
      return cached;
    }
    final parsed = parser(content);
    _byHash[hash] = parsed;
    if (_byHash.length > maxEntries) {
      _byHash.remove(_byHash.keys.first);
    }
    return parsed;
  }
}
