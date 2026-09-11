import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/incoming_link_source.dart';
import 'package:novel_viewer/features/text_download/domain/download_request.dart';
import 'package:novel_viewer/features/text_download/providers/download_request_providers.dart';

void main() {
  const novelUrl = 'https://ncode.syosetu.com/n1234ab/';
  const otherUrl = 'https://kakuyomu.jp/works/1';
  final novelLink = Uri.parse(
    'novelviewer://download?url=https%3A%2F%2Fncode.syosetu.com%2Fn1234ab%2F',
  );
  final otherLink = Uri.parse(
    'novelviewer://download?url=https%3A%2F%2Fkakuyomu.jp%2Fworks%2F1',
  );

  late StreamController<Uri> platform;
  late ProviderContainer container;
  late List<PendingDownloadRequest?> observed;

  setUp(() {
    platform = StreamController<Uri>();
    container = ProviderContainer.test(
      overrides: [
        incomingLinkSourceProvider.overrideWithValue(
          IncomingLinkSource(
            initialLink: Future.value(null),
            platformLinks: platform.stream,
          ),
        ),
      ],
    );
    observed = [];
    container.listen(
      pendingDownloadRequestProvider,
      (_, next) => observed.add(next),
      fireImmediately: true,
    );
  });

  tearDown(() async {
    if (!platform.isClosed) await platform.close();
  });

  group('pendingDownloadRequestProvider', () {
    test('starts with nothing pending', () {
      expect(container.read(pendingDownloadRequestProvider), isNull);
    });

    test('holds the target of a download link', () async {
      platform.add(novelLink);
      await pumpEventQueue();

      expect(
        container.read(pendingDownloadRequestProvider)?.url,
        Uri.parse(novelUrl),
      );
    });

    test('ignores a link that is not a download request', () async {
      platform.add(Uri.parse('novelviewer://other?url=$novelUrl'));
      platform.add(Uri.parse('novelviewer://download?url=file%3A%2F%2F%2Fx'));
      await pumpEventQueue();

      expect(container.read(pendingDownloadRequestProvider), isNull);
      expect(observed, [null]);
    });

    test('replaces an earlier pending target with a later one', () async {
      platform.add(novelLink);
      await pumpEventQueue();
      platform.add(otherLink);
      await pumpEventQueue();

      expect(
        container.read(pendingDownloadRequestProvider)?.url,
        Uri.parse(otherUrl),
      );
    });

    test('keeps working after a malformed link', () async {
      platform.add(Uri.parse('novelviewer://download?url=%FF'));
      await pumpEventQueue();
      platform.add(novelLink);
      await pumpEventQueue();

      expect(
        container.read(pendingDownloadRequestProvider)?.url,
        Uri.parse(novelUrl),
      );
    });

    test(
      'clears a request once it has been put in front of the reader',
      () async {
        platform.add(novelLink);
        await pumpEventQueue();
        final request = container.read(pendingDownloadRequestProvider)!;

        container
            .read(pendingDownloadRequestProvider.notifier)
            .markHandled(request);

        expect(container.read(pendingDownloadRequestProvider), isNull);
      },
    );

    test('keeps a newer request when an older one is marked handled', () async {
      // Two shares in a row: whoever handles the first must not throw away the
      // second, which nobody has seen yet.
      platform.add(novelLink);
      await pumpEventQueue();
      final first = container.read(pendingDownloadRequestProvider)!;
      platform.add(otherLink);
      await pumpEventQueue();

      container
          .read(pendingDownloadRequestProvider.notifier)
          .markHandled(first);

      expect(
        container.read(pendingDownloadRequestProvider)?.url,
        Uri.parse(otherUrl),
      );
    });

    test('notifies again when the same URL arrives twice', () async {
      // Sharing the same page a second time has to reach the dialog again, so
      // two requests for one URL must not compare equal.
      platform.add(novelLink);
      await pumpEventQueue();
      platform.add(novelLink);
      await pumpEventQueue();

      final requests = observed.whereType<PendingDownloadRequest>().toList();
      expect(requests, hasLength(2));
      expect(requests.first.url, requests.last.url);
      expect(requests.first, isNot(requests.last));
    });
  });

  group('PendingDownloadRequest', () {
    test('compares equal for the same URL and sequence', () {
      expect(
        PendingDownloadRequest(url: Uri.parse(novelUrl), sequence: 1),
        PendingDownloadRequest(url: Uri.parse(novelUrl), sequence: 1),
      );
    });

    test('differs when the sequence differs', () {
      expect(
        PendingDownloadRequest(url: Uri.parse(novelUrl), sequence: 1),
        isNot(PendingDownloadRequest(url: Uri.parse(novelUrl), sequence: 2)),
      );
    });
  });
}
