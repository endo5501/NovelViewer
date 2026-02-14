import 'package:novel_viewer/features/text_download/data/sites/narou_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/kakuyomu_site.dart';

class Episode {
  final int index;
  final String title;
  final Uri url;

  const Episode({
    required this.index,
    required this.title,
    required this.url,
  });
}

class NovelIndex {
  final String title;
  final List<Episode> episodes;
  final String? bodyContent;

  const NovelIndex({
    required this.title,
    required this.episodes,
    this.bodyContent,
  });
}

abstract class NovelSite {
  String get siteType;
  bool canHandle(Uri url);
  String extractNovelId(Uri url);
  NovelIndex parseIndex(String html, Uri baseUrl);
  String parseEpisode(String html);
}

class NovelSiteRegistry {
  final List<NovelSite> _sites = [
    NarouSite(),
    KakuyomuSite(),
  ];

  NovelSite? findSite(Uri url) {
    if (url.host.isEmpty) return null;
    for (final site in _sites) {
      if (site.canHandle(url)) return site;
    }
    return null;
  }
}
