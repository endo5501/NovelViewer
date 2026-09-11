import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

/// The custom URL scheme through which a download request reaches the app from
/// outside it: a browser, a shortcut, or (later) the iOS share sheet.
///
/// Registered in `Info.plist` on iOS and macOS only. Windows would start a
/// second process for a scheme launch, and two processes holding the same
/// SQLite files is a problem that has to be solved before the scheme can be
/// registered there.
const String downloadRequestScheme = 'novelviewer';

/// The only host [downloadRequestScheme] links are acted on for, leaving room
/// for other actions to be added later without widening what today's links do.
const String downloadRequestHost = 'download';

/// The query parameter carrying the (percent-encoded) URL to download.
const String downloadRequestUrlParameter = 'url';

/// Resolves the site adapters once: the registry is stateless, and the lookup
/// below runs for every incoming link.
final NovelSiteRegistry _registry = NovelSiteRegistry();

/// The URL a [link] asks the app to download, or null when [link] is not a
/// download request the app may act on.
///
/// Anything may open this scheme — a page the reader merely visited can, too —
/// so the result is only ever a *proposal*: it is shown in the download dialog
/// for confirmation and never downloaded on its own. What is rejected here is
/// what could not be confirmed meaningfully: links that do not name a target,
/// and targets that are not web pages.
///
/// Whether a dedicated site adapter claims the target is deliberately *not*
/// checked. [NovelSiteRegistry] falls back to the generic web adapter for any
/// other http(s) page, so rejecting here would make a shared link behave
/// differently from the same URL typed by hand.
Uri? downloadTargetFromLink(Uri link) {
  if (link.scheme != downloadRequestScheme) return null;
  if (link.host != downloadRequestHost) return null;

  final raw = link.queryParameters[downloadRequestUrlParameter];
  if (raw == null || raw.isEmpty) return null;

  final target = Uri.tryParse(raw);
  if (target == null) return null;

  // The same judgement the dialog applies to a typed URL: http(s) with a host.
  // Reusing the registry keeps the two from drifting apart.
  if (_registry.findSite(target) == null) return null;

  return target;
}

/// A download the app has been asked to perform from outside it, waiting for
/// the reader to confirm or dismiss it.
///
/// [sequence] distinguishes one request from the next, so that sharing the same
/// page twice produces two unequal values and reaches the dialog both times.
/// Without it the second share would assign an identical value and notify
/// nobody — the same reason `FileOpenRequestNotifier` counts its requests.
class PendingDownloadRequest {
  const PendingDownloadRequest({required this.url, required this.sequence});

  /// The page to download. Always an http(s) URL with a host.
  final Uri url;

  /// How many requests have arrived in this session, this one included.
  final int sequence;

  @override
  bool operator ==(Object other) =>
      other is PendingDownloadRequest &&
      other.url == url &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(url, sequence);

  @override
  String toString() => 'PendingDownloadRequest(url: $url, sequence: $sequence)';
}
