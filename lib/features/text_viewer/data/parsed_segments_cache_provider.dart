import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parsed_segments_cache.dart';

final parsedSegmentsCacheProvider =
    Provider<ParsedSegmentsCache>((ref) => ParsedSegmentsCache());
