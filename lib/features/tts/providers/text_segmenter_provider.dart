import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/text_segmenter.dart';

/// Shared, app-wide [TextSegmenter] instance.
///
/// `TextSegmenter` is currently stateless, so a singleton is fine. Routing
/// access through this provider lets us swap implementations or add
/// configuration (per-novel rules, language overrides, etc.) without
/// touching every controller that needs sentence segmentation.
final textSegmenterProvider =
    Provider<TextSegmenter>((ref) => const TextSegmenter());
