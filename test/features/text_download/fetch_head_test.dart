import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';

void main() {
  group('DownloadService.fetchHead', () {
    test('returns headers from HEAD response', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'HEAD');
        expect(request.url.toString(), 'https://ncode.syosetu.com/n9669bk/1/');
        return http.Response(
          '',
          200,
          headers: {
            'last-modified': 'Thu, 01 Jan 2025 00:00:00 GMT',
            'content-type': 'text/html',
          },
        );
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final headers = await service.fetchHead(
        Uri.parse('https://ncode.syosetu.com/n9669bk/1/'),
      );

      expect(headers, isNotNull);
      expect(headers!['last-modified'], 'Thu, 01 Jan 2025 00:00:00 GMT');
    });

    test('returns null when HEAD request fails', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 500);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final headers = await service.fetchHead(
        Uri.parse('https://ncode.syosetu.com/n9669bk/1/'),
      );

      expect(headers, isNull);
    });

    test('returns null when network error occurs', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final headers = await service.fetchHead(
        Uri.parse('https://ncode.syosetu.com/n9669bk/1/'),
      );

      expect(headers, isNull);
    });

    test('returns headers without last-modified when server does not provide it', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '',
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      final headers = await service.fetchHead(
        Uri.parse('https://ncode.syosetu.com/n9669bk/1/'),
      );

      expect(headers, isNotNull);
      expect(headers!.containsKey('last-modified'), isFalse);
    });

    test('sends User-Agent header with HEAD request', () async {
      String? capturedUserAgent;
      final mockClient = MockClient((request) async {
        capturedUserAgent = request.headers['user-agent'];
        return http.Response('', 200);
      });

      final service = DownloadService(
        client: mockClient,
        requestDelay: Duration.zero,
      );

      await service.fetchHead(
        Uri.parse('https://ncode.syosetu.com/n9669bk/1/'),
      );

      expect(capturedUserAgent, isNotNull);
      expect(capturedUserAgent, contains('Mozilla'));
    });
  });
}
