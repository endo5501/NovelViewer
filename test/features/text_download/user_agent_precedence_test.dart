import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';

import 'helpers/download_test_helpers.dart';

/// A fake site whose [requestHeaders] returns a fixed set of headers, used to
/// verify the User-Agent precedence contract (F120): a site-provided
/// User-Agent overrides the DownloadService default.
class _HeaderSite extends FakeNovelSite {
  final Map<String, String> headers;

  _HeaderSite(this.headers)
      : super(episodes: const [], bodyContent: '短編本文');

  @override
  Map<String, String> requestHeaders(Uri url) => headers;
}

void main() {
  group('User-Agent precedence (F120)', () {
    test('site-provided User-Agent overrides the default', () async {
      const siteUa = 'NovelViewer (Flutter desktop app)';
      final captured = <String, String>{};
      final client = capturingHeadersClient(captured);
      final service = DownloadService(client: client, requestDelay: Duration.zero);

      await service.downloadNovel(
        site: _HeaderSite(const {'User-Agent': siteUa}),
        url: Uri.parse('https://example.com/index'),
        outputPath: Directory.systemTemp.createTempSync('ua_test_').path,
      );

      expect(captured['user-agent'], siteUa);
    });

    test('default User-Agent is used when the site provides none', () async {
      final captured = <String, String>{};
      final client = capturingHeadersClient(captured);
      final service = DownloadService(client: client, requestDelay: Duration.zero);

      await service.downloadNovel(
        site: _HeaderSite(const {}),
        url: Uri.parse('https://example.com/index'),
        outputPath: Directory.systemTemp.createTempSync('ua_test_').path,
      );

      expect(captured['user-agent'], contains('Chrome'));
    });
  });
}
