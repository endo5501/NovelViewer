import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/app_update/data/github_release_client.dart';

void main() {
  group('GithubReleaseClient.fetchLatest', () {
    test('parses tag_name, body and assets from a 200 response', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.3.0',
            'body': '## Notes\n- a\n- b',
            'assets': [
              {
                'name': 'novel_viewer-setup-v1.3.0.exe',
                'browser_download_url':
                    'https://example.com/novel_viewer-setup-v1.3.0.exe',
              },
              {
                'name': 'novel_viewer-setup-v1.3.0.exe.sha256',
                'browser_download_url':
                    'https://example.com/novel_viewer-setup-v1.3.0.exe.sha256',
              },
            ],
          }),
          200,
        );
      });
      final client = GithubReleaseClient(
        httpClient: mock,
        userAgent: 'NovelViewer/1.2.0 (test)',
      );

      final info = await client.fetchLatest();

      expect(info.tagName, 'v1.3.0');
      expect(info.body, contains('Notes'));
      expect(info.assets, hasLength(2));
      expect(info.installerAsset()?.name, 'novel_viewer-setup-v1.3.0.exe');
      expect(
        info.installerSha256Asset()?.name,
        'novel_viewer-setup-v1.3.0.exe.sha256',
      );
    });

    test('sends a User-Agent header', () async {
      String? sentUserAgent;
      final mock = MockClient((request) async {
        sentUserAgent = request.headers['User-Agent'];
        return http.Response(
          jsonEncode({'tag_name': 'v1.0.0', 'body': '', 'assets': []}),
          200,
        );
      });
      final client = GithubReleaseClient(
        httpClient: mock,
        userAgent: 'NovelViewer/1.2.0 (https://github.com/endo5501/NovelViewer)',
      );

      await client.fetchLatest();

      expect(sentUserAgent,
          'NovelViewer/1.2.0 (https://github.com/endo5501/NovelViewer)');
    });

    test('treats null body as empty string', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'tag_name': 'v1.0.0', 'body': null, 'assets': []}),
          200,
        );
      });
      final client = GithubReleaseClient(
        httpClient: mock,
        userAgent: 'ua',
      );

      final info = await client.fetchLatest();

      expect(info.body, '');
    });

    test('throws GithubReleaseException on non-200 status', () async {
      final mock = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final client = GithubReleaseClient(httpClient: mock, userAgent: 'ua');

      expect(client.fetchLatest(), throwsA(isA<GithubReleaseException>()));
    });

    test('throws GithubReleaseException on malformed JSON', () async {
      final mock = MockClient((request) async {
        return http.Response('not-json', 200);
      });
      final client = GithubReleaseClient(httpClient: mock, userAgent: 'ua');

      expect(client.fetchLatest(), throwsA(isA<GithubReleaseException>()));
    });

    test('installerAsset returns null when no matching asset exists', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.0.0',
            'body': '',
            'assets': [
              {
                'name': 'novel_viewer-windows-x64-v1.0.0.zip',
                'browser_download_url': 'https://example.com/zip',
              },
            ],
          }),
          200,
        );
      });
      final client = GithubReleaseClient(httpClient: mock, userAgent: 'ua');

      final info = await client.fetchLatest();

      expect(info.installerAsset(), isNull);
      expect(info.installerSha256Asset(), isNull);
    });
  });
}
