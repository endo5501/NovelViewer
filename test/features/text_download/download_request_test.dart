import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/domain/download_request.dart';

void main() {
  group('downloadTargetFromLink', () {
    test('accepts a well-formed download link', () {
      final target = downloadTargetFromLink(
        Uri.parse(
          'novelviewer://download?url=https%3A%2F%2Fncode.syosetu.com%2Fn1234ab%2F',
        ),
      );
      expect(target, Uri.parse('https://ncode.syosetu.com/n1234ab/'));
    });

    test('preserves the query string of the target URL', () {
      final target = downloadTargetFromLink(
        Uri.parse(
          'novelviewer://download?url=https%3A%2F%2Fkakuyomu.jp%2Fworks%2F1%3Fpage%3D2%26x%3Dy',
        ),
      );
      expect(target, Uri.parse('https://kakuyomu.jp/works/1?page=2&x=y'));
    });

    test('accepts an http target, not only https', () {
      final target = downloadTargetFromLink(
        Uri.parse(
          'novelviewer://download?url=http%3A%2F%2Fwww.aozora.gr.jp%2Fcards%2F1%2F',
        ),
      );
      expect(target, Uri.parse('http://www.aozora.gr.jp/cards/1/'));
    });

    test('accepts a target no dedicated site adapter claims', () {
      // The generic web fallback handles arbitrary pages, so "not a novel site"
      // is not a reason to reject a request here. Sorting that out is the
      // dialog's job, exactly as it is for a hand-typed URL.
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download?url=https%3A%2F%2Fexample.com%2Fa'),
      );
      expect(target, Uri.parse('https://example.com/a'));
    });

    test('rejects a link with another scheme', () {
      final target = downloadTargetFromLink(
        Uri.parse('https://download/?url=https%3A%2F%2Fexample.com%2F'),
      );
      expect(target, isNull);
    });

    test('rejects a link with a host other than download', () {
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://other?url=https%3A%2F%2Fexample.com%2F'),
      );
      expect(target, isNull);
    });

    test('rejects a link without a url parameter', () {
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download'),
      );
      expect(target, isNull);
    });

    test('rejects a link whose url parameter is empty', () {
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download?url='),
      );
      expect(target, isNull);
    });

    test('rejects a target with a non-web scheme', () {
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download?url=file%3A%2F%2F%2Fetc%2Fpasswd'),
      );
      expect(target, isNull);
    });

    test('rejects a target without a scheme', () {
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download?url=not%20a%20url'),
      );
      expect(target, isNull);
    });

    test('rejects a target that cannot be parsed', () {
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download?url=http%3A%2F%2F%5B'),
      );
      expect(target, isNull);
    });

    test('rejects a link whose query is not valid UTF-8', () {
      // Reading the query decodes percent escapes as UTF-8 and throws on bad
      // bytes. Anything can open this scheme, so a malformed one has to be
      // turned away rather than allowed to escape as an error.
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download?url=%FF'),
      );
      expect(target, isNull);
    });

    test('rejects a web target with an empty host', () {
      final target = downloadTargetFromLink(
        Uri.parse('novelviewer://download?url=https%3A%2F%2F'),
      );
      expect(target, isNull);
    });
  });
}
