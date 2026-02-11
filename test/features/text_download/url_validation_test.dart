import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

void main() {
  late NovelSiteRegistry registry;

  setUp(() {
    registry = NovelSiteRegistry();
  });

  group('URL validation', () {
    test('accepts ncode.syosetu.com URLs', () {
      final site =
          registry.findSite(Uri.parse('https://ncode.syosetu.com/n9669bk/'));
      expect(site, isNotNull);
    });

    test('accepts novel18.syosetu.com URLs', () {
      final site = registry
          .findSite(Uri.parse('https://novel18.syosetu.com/n1234ab/'));
      expect(site, isNotNull);
    });

    test('accepts kakuyomu.jp URLs', () {
      final site = registry.findSite(
          Uri.parse('https://kakuyomu.jp/works/1177354054881162325'));
      expect(site, isNotNull);
    });

    test('rejects unknown domains', () {
      final site =
          registry.findSite(Uri.parse('https://example.com/novel/123'));
      expect(site, isNull);
    });

    test('rejects empty URLs', () {
      final site = registry.findSite(Uri.parse(''));
      expect(site, isNull);
    });

    test('rejects non-URL strings', () {
      final site = registry.findSite(Uri.parse('not-a-url'));
      expect(site, isNull);
    });

    test('accepts narou URL with episode path', () {
      final site = registry
          .findSite(Uri.parse('https://ncode.syosetu.com/n9669bk/1/'));
      expect(site, isNotNull);
    });

    test('accepts kakuyomu URL with episode path', () {
      final site = registry.findSite(Uri.parse(
          'https://kakuyomu.jp/works/1177354054881162325/episodes/1'));
      expect(site, isNotNull);
    });
  });
}
