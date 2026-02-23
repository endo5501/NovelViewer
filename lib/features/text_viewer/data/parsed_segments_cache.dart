import 'package:novel_viewer/features/text_viewer/data/ruby_text_parser.dart';
import 'package:novel_viewer/features/text_viewer/data/text_segment.dart';

class ParsedSegmentsCache {
  String? _lastContent;
  List<TextSegment>? _cachedSegments;

  List<TextSegment> getSegments(String content) {
    if (content != _lastContent) {
      _lastContent = content;
      _cachedSegments = parseRubyText(content);
    }
    return _cachedSegments!;
  }
}
