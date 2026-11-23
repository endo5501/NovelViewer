import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/remote_novel_candidates.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';

RemoteProgress _remote(
  String novelId, {
  String device = 'pad',
  int episode = 1,
  required DateTime readAt,
  String? url = 'ok',
  String? title,
}) {
  return RemoteProgress(
    deviceId: device,
    deviceName: '$device-name',
    record: SyncProgressRecord(
      novelId: novelId,
      episode: episode,
      fileName: '$episode.txt',
      bodyOffset: 0,
      bodyHash: null,
      readAt: readAt,
      url: url,
      title: title,
    ),
  );
}

void main() {
  final d1 = DateTime.utc(2026, 11, 20);
  final d2 = DateTime.utc(2026, 11, 21);
  final d3 = DateTime.utc(2026, 11, 22);

  // Accepts only the url 'ok', so a test can say which urls pass.
  bool urlMatches(String url, String novelId) => url == 'ok';

  List<RemoteProgress> build(
    List<RemoteProgress> remote, {
    Set<String> registered = const {},
  }) {
    return buildRemoteNovelCandidates(
      remote: remote,
      registeredFolderNames: registered,
      urlMatches: urlMatches,
    );
  }

  test('leaves out a novel this device already has', () {
    final result = build(
      [_remote('narou_a', readAt: d1), _remote('kakuyomu_1', readAt: d1)],
      registered: {'narou_a'},
    );

    expect(result.map((r) => r.record.novelId), ['kakuyomu_1']);
  });

  test('leaves out a record without a url', () {
    final result = build([
      _remote('hameln_1', readAt: d1, url: null),
      _remote('narou_b', readAt: d1),
    ]);

    expect(result.map((r) => r.record.novelId), ['narou_b']);
  });

  test('leaves out a record whose url does not lead to the novel', () {
    final result = build([
      _remote('narou_a', readAt: d1, url: 'elsewhere'),
      _remote('narou_b', readAt: d1),
    ]);

    expect(result.map((r) => r.record.novelId), ['narou_b']);
  });

  test('keeps one row per novel, the newest read', () {
    final result = build([
      _remote('narou_a', device: 'mac', episode: 5, readAt: d1),
      _remote('narou_a', device: 'pad', episode: 42, readAt: d3),
      _remote('narou_a', device: 'win', episode: 9, readAt: d2),
    ]);

    expect(result, hasLength(1));
    expect(result.single.deviceId, 'pad');
    expect(result.single.record.episode, 42);
  });

  test('the newest read with a usable url wins', () {
    // The newest device runs an old build and sent no url.
    final result = build([
      _remote('narou_a', device: 'mac', episode: 5, readAt: d1),
      _remote('narou_a', device: 'old', episode: 9, readAt: d3, url: null),
    ]);

    expect(result.single.deviceId, 'mac');
  });

  test('orders the novels newest read first', () {
    final result = build([
      _remote('narou_a', readAt: d1),
      _remote('narou_c', readAt: d3),
      _remote('narou_b', readAt: d2),
    ]);

    expect(result.map((r) => r.record.novelId), [
      'narou_c',
      'narou_b',
      'narou_a',
    ]);
  });

  test('is empty without records', () {
    expect(build(const []), isEmpty);
  });
}
