import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:logging/logging.dart';

final _log = Logger('text_download.links');

/// Every link the app is opened with or receives while running, delivered
/// exactly once.
///
/// The platform hands these in over two separate channels — one future for the
/// link that launched the app, one stream for the rest — and whether the launch
/// link is *also* replayed on the stream is not something the app can rely on
/// either way. Reconciling the two is done here, once, so the rest of the app
/// sees a single ordered stream and never has to guard against acting on the
/// same launch twice.
///
/// The links themselves are not interpreted here; see `downloadTargetFromLink`.
class IncomingLinkSource {
  IncomingLinkSource({
    required Future<Uri?> initialLink,
    required Stream<Uri> platformLinks,
  }) : _initialLink = initialLink,
       _platformLinks = platformLinks;

  /// A source that delivers nothing, and touches no platform channel.
  ///
  /// The default everywhere except a running app: [appLinks] reaches an event
  /// channel that only exists behind a real engine, and merely subscribing to
  /// it outside one is reported as an unhandled plugin error.
  factory IncomingLinkSource.none() => IncomingLinkSource(
    initialLink: Future.value(null),
    platformLinks: const Stream.empty(),
  );

  /// The running app's source, reading both channels from `app_links`.
  factory IncomingLinkSource.appLinks() {
    final appLinks = AppLinks();
    return IncomingLinkSource(
      initialLink: appLinks.getInitialLink(),
      platformLinks: appLinks.uriLinkStream,
    );
  }

  final Future<Uri?> _initialLink;
  final Stream<Uri> _platformLinks;

  /// The merged links, in arrival order with the launch link first.
  ///
  /// Nothing is read from either channel until this is listened to, and the
  /// stream closes when the platform stream does.
  Stream<Uri> get links {
    final controller = StreamController<Uri>();
    final buffered = <Uri>[];
    var initialSettled = false;
    Uri? initial;
    var firstPlatformLinkSeen = false;
    StreamSubscription<Uri>? subscription;

    // The launch link may or may not be replayed as the platform stream's first
    // event. Drop that one event when it matches; every later repeat is a real
    // one the reader asked for.
    void forward(Uri link) {
      if (controller.isClosed) return;
      if (!firstPlatformLinkSeen) {
        firstPlatformLinkSeen = true;
        if (link == initial) return;
      }
      controller.add(link);
    }

    void settleInitial(Uri? link) {
      initial = link;
      initialSettled = true;
      // The platform stream may already be gone; its closing closed this one.
      if (controller.isClosed) return;
      if (link != null) controller.add(link);
      buffered.forEach(forward);
      buffered.clear();
    }

    controller.onListen = () {
      subscription = _platformLinks.listen(
        (link) => initialSettled ? forward(link) : buffered.add(link),
        // A failing channel — no plugin registered on this platform, a decoding
        // error — means links will not arrive, which is nothing a consumer can
        // act on. Forwarding it would only turn "no links" into a crash.
        onError: (Object error, StackTrace stackTrace) => _log.fine(
          'Ignoring an error from the platform link channel',
          error,
        ),
        onDone: controller.close,
      );
      // A failure to read the launch link says nothing about the links that
      // follow, so it settles as "the app was not opened with one".
      _initialLink.then(settleInitial, onError: (_, _) => settleInitial(null));
    };
    controller.onCancel = () async {
      await subscription?.cancel();
      subscription = null;
    };

    return controller.stream;
  }
}
