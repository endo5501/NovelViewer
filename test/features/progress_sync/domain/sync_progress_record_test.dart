import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';

SyncProgressRecord _rec({String? url, String? title}) {
  return SyncProgressRecord(
    novelId: 'narou_n1234ab',
    episode: 3,
    fileName: '003_t.txt',
    bodyOffset: 100,
    bodyHash: 'h',
    readAt: DateTime.utc(2026, 11, 1),
    url: url,
    title: title,
  );
}

void main() {
  const url = 'https://ncode.syosetu.com/n1234ab/';

  test('records that differ only in the url are not equal', () {
    expect(_rec(url: url, title: 'a'), isNot(_rec(title: 'a')));
  });

  test('records that differ only in the title are not equal', () {
    expect(_rec(url: url, title: 'a'), isNot(_rec(url: url, title: 'b')));
  });

  test('records with the same url and title are equal and hash alike', () {
    expect(_rec(url: url, title: 'a'), _rec(url: url, title: 'a'));
    expect(
      _rec(url: url, title: 'a').hashCode,
      _rec(url: url, title: 'a').hashCode,
    );
  });

  test('url and title default to null', () {
    final record = SyncProgressRecord(
      novelId: 'narou_a',
      episode: 1,
      fileName: '1.txt',
      bodyOffset: 0,
      bodyHash: null,
      readAt: DateTime.utc(2026, 11, 1),
    );

    expect(record.url, isNull);
    expect(record.title, isNull);
  });
}
