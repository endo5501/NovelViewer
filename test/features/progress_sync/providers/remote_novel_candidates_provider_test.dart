import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:novel_viewer/features/novel_metadata_db/data/novel_database.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_repository.dart';
import 'package:novel_viewer/features/progress_sync/domain/device_progress.dart';
import 'package:novel_viewer/features/progress_sync/domain/sync_progress_record.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_config_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/remote_novel_candidates_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/novel_metadata_db_fixture.dart';

/// Counts the reads of the received records.
class _CountingRepository extends ProgressSyncRepository {
  _CountingRepository(super.novelDatabase);

  int remoteReads = 0;

  @override
  Future<List<RemoteProgress>> findAllRemote() {
    remoteReads++;
    return super.findAllRemote();
  }
}

NovelMetadata _novel(String folderName) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName.substring('narou_'.length),
  title: folderName,
  url: 'https://ncode.syosetu.com/${folderName.substring(6)}/',
  folderName: folderName,
  episodeCount: 1,
  downloadedAt: DateTime(2026, 1, 1),
);

SyncProgressRecord _record(String ncode, {required DateTime readAt}) {
  return SyncProgressRecord(
    novelId: 'narou_$ncode',
    episode: 3,
    fileName: '003.txt',
    bodyOffset: 0,
    bodyHash: null,
    readAt: readAt,
    url: 'https://ncode.syosetu.com/$ncode/',
    title: 'title $ncode',
  );
}

void main() {
  late NovelDatabase novelDatabase;
  late _CountingRepository repository;
  late StreamController<void> pulls;
  late List<NovelMetadata> registered;
  late int requests;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    novelDatabase = await seedNovelDatabaseFixture();
    repository = _CountingRepository(novelDatabase);
    pulls = StreamController<void>.broadcast();
    addTearDown(pulls.close);
    registered = [];
    requests = 0;
  });

  tearDown(() async {
    await novelDatabase.close();
  });

  Future<void> receive(List<SyncProgressRecord> records) {
    return repository.replaceRemote(
      selfDeviceId: 'self',
      devices: [
        DeviceProgress(deviceId: 'pad', deviceName: 'iPad', records: records),
      ],
    );
  }

  ProviderContainer container({
    bool available = true,
    SyncAccountState account = const SyncAccountState.signedIn('a@b.c'),
  }) {
    final c = ProviderContainer(
      overrides: [
        progressSyncAvailableProvider.overrideWithValue(available),
        syncAccountStateProvider.overrideWithValue(account),
        progressSyncRepositoryProvider.overrideWithValue(repository),
        progressSyncPulledProvider.overrideWithValue(pulls.stream),
        allNovelsProvider.overrideWith((ref) => registered),
        syncHttpClientProvider.overrideWithValue(
          MockClient((_) async {
            requests++;
            return http.Response('', 500);
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Keep it alive across reads, as the dialog watching it does.
    c.listen(remoteNovelCandidatesProvider, (_, _) {});
    return c;
  }

  test('lists the received novels this device does not have', () async {
    await receive([
      _record('n1', readAt: DateTime.utc(2026, 11, 1)),
      _record('n2', readAt: DateTime.utc(2026, 11, 2)),
    ]);
    registered = [_novel('narou_n1')];
    final c = container();

    final result = await c.read(remoteNovelCandidatesProvider.future);

    expect(result.map((r) => r.record.novelId), ['narou_n2']);
    expect(requests, 0);
  });

  test('is empty without reading the records in a build without sync',
      () async {
    await receive([_record('n1', readAt: DateTime.utc(2026, 11, 1))]);
    final c = container(available: false);

    expect(await c.read(remoteNovelCandidatesProvider.future), isEmpty);
    expect(repository.remoteReads, 0);
    expect(requests, 0);
  });

  test('is empty without reading the records while signed out', () async {
    await receive([_record('n1', readAt: DateTime.utc(2026, 11, 1))]);
    final c = container(account: const SyncAccountState.signedOut());

    expect(await c.read(remoteNovelCandidatesProvider.future), isEmpty);
    expect(repository.remoteReads, 0);
  });

  test('is empty without reading the records when sign-in expired', () async {
    await receive([_record('n1', readAt: DateTime.utc(2026, 11, 1))]);
    final c = container(account: const SyncAccountState.needsReauth('a@b.c'));

    expect(await c.read(remoteNovelCandidatesProvider.future), isEmpty);
    expect(repository.remoteReads, 0);
  });

  test('is rebuilt after each pull', () async {
    final c = container();
    expect(await c.read(remoteNovelCandidatesProvider.future), isEmpty);

    await receive([_record('n1', readAt: DateTime.utc(2026, 11, 1))]);
    pulls.add(null);
    await Future<void>.delayed(Duration.zero);

    final result = await c.read(remoteNovelCandidatesProvider.future);
    expect(result.map((r) => r.record.novelId), ['narou_n1']);
    expect(requests, 0);
  });

  test('a novel drops out once it is registered here', () async {
    await receive([_record('n1', readAt: DateTime.utc(2026, 11, 1))]);
    final c = container();
    expect(await c.read(remoteNovelCandidatesProvider.future), hasLength(1));

    registered = [_novel('narou_n1')];
    c.invalidate(allNovelsProvider);

    expect(await c.read(remoteNovelCandidatesProvider.future), isEmpty);
  });
}
