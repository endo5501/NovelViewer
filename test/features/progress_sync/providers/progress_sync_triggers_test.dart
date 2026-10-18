import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/domain/novel_metadata.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/progress_sync/data/oauth/google_authorization.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/domain/oauth_client.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_triggers.dart';

class _RecordingRunner implements ProgressSyncRunner {
  final List<String> calls = [];
  Completer<void>? pushGate;

  @override
  Future<void> push() async {
    calls.add('push');
    await pushGate?.future;
  }

  @override
  Future<void> pull() async => calls.add('pull');

  @override
  Future<void> syncNow() async => calls.add('syncNow');

  @override
  Future<void> get idle async {}
}

NovelMetadata _novel(String folderName) => NovelMetadata(
  siteType: 'narou',
  novelId: folderName,
  title: folderName,
  url: 'https://example.com/$folderName',
  folderName: folderName,
  episodeCount: 1,
  downloadedAt: DateTime(2026, 1, 1),
);

class _MemoryCredentials implements SyncCredentialStore {
  StoredCredentials? stored;

  @override
  Future<StoredCredentials?> read() async => stored;

  @override
  Future<void> write(StoredCredentials credentials) async =>
      stored = credentials;

  @override
  Future<void> delete() async => stored = null;
}

class _NoReceiver implements AuthorizationCodeReceiver {
  @override
  Future<AuthorizationCode?> obtainCode({
    required Uri Function(String redirectUri) authorizationUrl,
    required String state,
  }) async => null;
}

ProgressSyncAuth _auth(_MemoryCredentials credentials) => ProgressSyncAuth(
  client: const OAuthClient(
    signIn: ProgressSyncSignIn.desktop,
    clientId: 'cid',
    clientSecret: 's',
  ),
  receiver: _NoReceiver(),
  credentials: credentials,
  httpClient: MockClient((_) async => http.Response('', 500)),
  clearSyncState: () async {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('progressSyncStartupProvider', () {
    test(
      'restores the account, then pushes and pulls when signed in',
      () async {
        final runner = _RecordingRunner();
        final credentials = _MemoryCredentials()
          ..stored = const StoredCredentials(
            refreshToken: 'rt',
            email: 'reader@example.com',
          );
        final auth = _auth(credentials);
        final container = ProviderContainer(
          overrides: [
            progressSyncRunnerProvider.overrideWithValue(runner),
            progressSyncAuthProvider.overrideWithValue(auth),
          ],
        );
        addTearDown(container.dispose);

        await container.read(progressSyncStartupProvider.future);

        expect(auth.state.value.status, SyncAccountStatus.signedIn);
        // A push the last run made on its way out may have been cut short;
        // nothing else would send it again until the reader leaves a novel.
        expect(runner.calls, ['syncNow']);
      },
    );

    test('does not pull while signed out', () async {
      final runner = _RecordingRunner();
      final container = ProviderContainer(
        overrides: [
          progressSyncRunnerProvider.overrideWithValue(runner),
          progressSyncAuthProvider.overrideWithValue(
            _auth(_MemoryCredentials()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(progressSyncStartupProvider.future);

      expect(runner.calls, isEmpty);
    });

    test('does nothing in a build without sync', () async {
      final runner = _RecordingRunner();
      final container = ProviderContainer(
        overrides: [
          progressSyncRunnerProvider.overrideWithValue(runner),
          progressSyncAuthProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(progressSyncStartupProvider.future);

      expect(runner.calls, isEmpty);
    });
  });

  group('ProgressSyncLifecycle', () {
    late _RecordingRunner runner;
    late ProgressSyncLifecycle lifecycle;

    setUp(() {
      runner = _RecordingRunner();
      lifecycle = ProgressSyncLifecycle(
        runner,
        exitTimeout: const Duration(milliseconds: 50),
      );
    });

    test('pulls when the app comes back to the front', () {
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(runner.calls, ['pull']);
    });

    test('pushes when the app is hidden or paused', () {
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(runner.calls, ['push', 'push']);
    });

    test('does not push when a desktop window only loses focus', () {
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(runner.calls, isEmpty);
    });

    test('pushes on an exit request and lets the app exit', () async {
      expect(await lifecycle.didRequestAppExit(), AppExitResponse.exit);
      expect(runner.calls, ['push']);
    });

    test('does not hold up exit for a push that hangs', () async {
      runner.pushGate = Completer<void>();
      final stopwatch = Stopwatch()..start();

      expect(await lifecycle.didRequestAppExit(), AppExitResponse.exit);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('progressSyncLeaveNovelListenerProvider', () {
    late _RecordingRunner runner;
    late ProviderContainer container;

    setUp(() {
      runner = _RecordingRunner();
      container = ProviderContainer(
        overrides: [
          progressSyncRunnerProvider.overrideWithValue(runner),
          libraryPathProvider.overrideWithValue('/library'),
          currentDirectoryProvider.overrideWith(
            () => CurrentDirectoryNotifier('/library/narou_a'),
          ),
          allNovelsProvider.overrideWith(
            (ref) => [_novel('narou_a'), _novel('narou_b')],
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(progressSyncLeaveNovelListenerProvider);
    });

    Future<void> moveTo(String directory) async {
      container.read(currentDirectoryProvider.notifier).setDirectory(directory);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('pushes on leaving a novel for the library root', () async {
      await moveTo('/library');
      expect(runner.calls, ['push']);
    });

    test('pushes on moving to another novel', () async {
      await moveTo('/library/narou_b');
      expect(runner.calls, ['push']);
    });

    test('pushes on moving to a folder that is not a novel', () async {
      await moveTo('/library/お気に入り');
      expect(runner.calls, ['push']);
    });

    test('does not push while moving inside the same novel', () async {
      await moveTo('/library/narou_a/sub');
      expect(runner.calls, isEmpty);
    });

    test('does not push on entering a novel from outside', () async {
      await moveTo('/library');
      runner.calls.clear();
      await moveTo('/library/narou_b');
      expect(runner.calls, isEmpty);
    });
  });
}
