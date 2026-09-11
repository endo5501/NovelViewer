import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/incoming_link_source.dart';

void main() {
  final first = Uri.parse(
    'novelviewer://download?url=https%3A%2F%2Fa.test%2F1',
  );
  final second = Uri.parse(
    'novelviewer://download?url=https%3A%2F%2Fa.test%2F2',
  );

  late StreamController<Uri> platform;
  late Completer<Uri?> initial;
  late IncomingLinkSource source;
  late List<Uri> delivered;
  StreamSubscription<Uri>? subscription;

  /// Starts collecting into [delivered]. Nothing reaches the source before it
  /// is listened to, so every test subscribes before driving the inputs.
  void listen({void Function()? onDone}) {
    subscription = source.links.listen(delivered.add, onDone: onDone);
  }

  setUp(() {
    platform = StreamController<Uri>();
    initial = Completer<Uri?>();
    source = IncomingLinkSource(
      initialLink: initial.future,
      platformLinks: platform.stream,
    );
    delivered = [];
    subscription = null;
  });

  tearDown(() async {
    await subscription?.cancel();
    // Not awaited: closing a single-subscription controller that was never
    // listened to does not complete until something drains it, and the tests
    // that skip the fixture leave it exactly so.
    if (!platform.isClosed) unawaited(platform.close());
  });

  group('IncomingLinkSource', () {
    test('delivers the link the app was opened with', () async {
      listen();
      initial.complete(first);
      await pumpEventQueue();

      expect(delivered, [first]);
    });

    test('delivers links received while the app is running', () async {
      listen();
      initial.complete(null);
      await pumpEventQueue();
      platform.add(first);
      platform.add(second);
      await pumpEventQueue();

      expect(delivered, [first, second]);
    });

    test('does not deliver the initial link twice when replayed', () async {
      // Whether the platform channel replays the link the app was launched
      // with is not something the app can rely on either way, so the replay is
      // absorbed here rather than guarded against at every call site.
      listen();
      initial.complete(first);
      await pumpEventQueue();
      platform.add(first);
      await pumpEventQueue();

      expect(delivered, [first]);
    });

    test(
      'absorbs a replay arriving before the initial link resolves',
      () async {
        listen();
        platform.add(first);
        await pumpEventQueue();
        initial.complete(first);
        await pumpEventQueue();

        expect(delivered, [first]);
      },
    );

    test('delivers a link received while running after the initial', () async {
      listen();
      platform.add(second);
      await pumpEventQueue();
      initial.complete(first);
      await pumpEventQueue();

      expect(delivered, [first, second]);
    });

    test('delivers the same URL again when opened a second time', () async {
      // Sharing the same page twice is an ordinary thing to do; only the launch
      // replay is absorbed, never a genuine repeat.
      listen();
      initial.complete(first);
      await pumpEventQueue();
      platform.add(first);
      platform.add(first);
      await pumpEventQueue();

      expect(delivered, [first, first]);
    });

    test('delivers nothing when the app was not opened with a link', () async {
      listen();
      initial.complete(null);
      await pumpEventQueue();

      expect(delivered, isEmpty);
    });

    test('keeps delivering links when the initial lookup fails', () async {
      listen();
      initial.completeError(StateError('no initial link'));
      await pumpEventQueue();
      platform.add(first);
      await pumpEventQueue();

      expect(delivered, [first]);
    });

    test('keeps going when the platform stream reports an error', () async {
      // A failing platform channel — no plugin registered on this platform, a
      // channel error — means no links will arrive, which is nothing a consumer
      // can act on. Forwarding it would only turn "no links" into a crash.
      listen();
      initial.complete(null);
      await pumpEventQueue();
      platform.addError(StateError('no plugin'));
      await pumpEventQueue();
      platform.add(first);
      await pumpEventQueue();

      expect(delivered, [first]);
    });

    test('delivers what it has when the platform stream closes first', () async {
      // Ordering between the two channels is not the app's to control. A launch
      // link that settles after the stream is gone is still a link the reader
      // asked for, so closing waits for it rather than dropping it.
      var closed = false;
      listen(onDone: () => closed = true);
      platform.add(second);
      await pumpEventQueue();
      await platform.close();
      await pumpEventQueue();
      expect(closed, isFalse, reason: 'still waiting for the launch link');

      initial.complete(first);
      await pumpEventQueue();

      expect(delivered, [first, second]);
      expect(closed, isTrue);
    });

    test('delivers nothing through the inert source', () async {
      // The default outside a running app: no platform channel is touched.
      expect(await IncomingLinkSource.none().links.toList(), isEmpty);
    });

    test('closes once the platform stream is done', () async {
      var closed = false;
      listen(onDone: () => closed = true);
      initial.complete(null);
      await pumpEventQueue();
      await platform.close();
      await pumpEventQueue();

      expect(closed, isTrue);
    });
  });
}
