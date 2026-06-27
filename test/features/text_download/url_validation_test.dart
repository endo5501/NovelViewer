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

    test('resolves unknown domains to the generic web fallback', () {
      // Behavior change: with the generic web fallback registered last, any
      // http(s) URL no longer specialized resolves to siteType 'web' instead of
      // being rejected. Importing arbitrary pages is the point of the feature.
      final site =
          registry.findSite(Uri.parse('https://example.com/novel/123'));
      expect(site, isNotNull);
      expect(site!.siteType, 'web');
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

  group('URL validation hardening (F119)', () {
    // After the generic web fallback, the security property F119 guards is no
    // longer "reject", but "never let a specialized adapter (e.g. Kakuyomu)
    // claim a look-alike / malformed URL". Such URLs now fall through to the
    // generic 'web' adapter and are fetched as the plain page the user pasted,
    // not misparsed as Kakuyomu. So we assert siteType == 'web' (not Kakuyomu).
    test('look-alike Kakuyomu host is not treated as Kakuyomu (web fallback)',
        () {
      final site = registry
          .findSite(Uri.parse('https://kakuyomu.jp.evil.com/works/123'));
      expect(site, isNotNull);
      expect(site!.siteType, 'web');
    });

    test('accepts www.kakuyomu.jp host', () {
      final site = registry
          .findSite(Uri.parse('https://www.kakuyomu.jp/works/123'));
      expect(site, isNotNull);
      expect(site!.siteType, isNot('web'));
    });

    test('Kakuyomu URL without a /works/ path falls back to web', () {
      final site = registry.findSite(Uri.parse('https://kakuyomu.jp/'));
      expect(site, isNotNull);
      expect(site!.siteType, 'web');
    });

    test('Kakuyomu URL where /works/ is not the leading segment falls back to web',
        () {
      final site =
          registry.findSite(Uri.parse('https://kakuyomu.jp/foo/works/123'));
      expect(site, isNotNull);
      expect(site!.siteType, 'web');
    });

    test('Kakuyomu URL with a non-numeric work id falls back to web', () {
      final site =
          registry.findSite(Uri.parse('https://kakuyomu.jp/works/123abc'));
      expect(site, isNotNull);
      expect(site!.siteType, 'web');
    });

    test('still accepts a Kakuyomu episode URL', () {
      final site = registry.findSite(
          Uri.parse('https://kakuyomu.jp/works/123/episodes/456'));
      expect(site, isNotNull);
    });

    test('rejects a non-web scheme (ftp)', () {
      final site =
          registry.findSite(Uri.parse('ftp://kakuyomu.jp/works/123'));
      expect(site, isNull);
    });

    test('accepts http URL for a supported host (upgraded to https on normalize)',
        () {
      final url = Uri.parse('http://www.aozora.gr.jp/cards/001779/files/x.html');
      final site = registry.findSite(url);
      expect(site, isNotNull);
      // normalizeUrl upgrades the scheme so the fetch / stored URL is https.
      expect(site!.normalizeUrl(url).scheme, 'https');
    });

    test('accepts http Narou URL and normalizes it to https', () {
      final url = Uri.parse('http://ncode.syosetu.com/n9669bk/');
      final site = registry.findSite(url);
      expect(site, isNotNull);
      expect(site!.normalizeUrl(url).scheme, 'https');
    });
  });
}
