import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/text_download/data/incoming_link_source.dart';
import 'package:novel_viewer/features/text_download/domain/download_request.dart';

final _log = Logger('text_download.request');

/// Where incoming links come from.
///
/// Defaults to the source that delivers nothing, and `main` overrides it with
/// the one backed by `app_links`. The platform channel behind that one only
/// exists inside a running app, and merely subscribing to it elsewhere is
/// reported as an unhandled plugin error — so a widget test gets the inert
/// default without having to know this provider exists.
final incomingLinkSourceProvider = Provider<IncomingLinkSource>(
  (ref) => IncomingLinkSource.none(),
);

/// The download the app has most recently been asked to perform from outside
/// it, or null when there is nothing waiting.
///
/// This notifier only ever *records* a request. Starting a download stays with
/// the dialog's own button, because anything at all can open the app's URL
/// scheme — a page the reader merely visited included — and a download must
/// never follow from that alone.
class PendingDownloadRequestNotifier extends Notifier<PendingDownloadRequest?> {
  int _received = 0;

  @override
  PendingDownloadRequest? build() {
    final subscription = ref
        .watch(incomingLinkSourceProvider)
        .links
        .listen(_onLink);
    ref.onDispose(subscription.cancel);
    return null;
  }

  void _onLink(Uri link) {
    final target = downloadTargetFromLink(link);
    if (target == null) {
      // Silently, on purpose: a rejection shown on screen would let any page
      // that opens the scheme put a message in front of the reader.
      _log.fine('Ignoring an incoming link that is not a download request');
      return;
    }
    _received += 1;
    state = PendingDownloadRequest(url: target, sequence: _received);
  }
}

final pendingDownloadRequestProvider =
    NotifierProvider<PendingDownloadRequestNotifier, PendingDownloadRequest?>(
      PendingDownloadRequestNotifier.new,
    );
