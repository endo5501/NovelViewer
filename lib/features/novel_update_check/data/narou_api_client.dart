import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

final _log = Logger('novel_update_check');

/// Reads the total episode count of Narou works through the official novel
/// API, many works per request, without touching their index pages.
///
/// The API returns `[{allcount}, {ncode: "N1234AB", general_all_no}, ...]`
/// in no particular order, and ignores an ncode filter that is entirely
/// invalid (returning unrelated works). So every response is matched against
/// the ncodes actually asked for: anything else is dropped, and an asked-for
/// ncode the response does not list is reported as failed (null).
class NarouApiClient {
  static const _host = 'api.syosetu.com';
  static const _generalPath = '/novelapi/api/';
  static const _r18Path = '/novel18api/api/';

  /// Works per request. The API accepts up to 500 results per call; 100 keeps
  /// the hyphen-joined `ncode` parameter well inside URL length limits.
  static const chunkSize = 100;

  /// The API answers an empty User-Agent with HTTP 403, so one is always sent.
  static const _userAgent = 'NovelViewer';

  final http.Client _client;
  final Duration requestDelay;
  final Duration requestTimeout;

  NarouApiClient({
    required http.Client client,
    this.requestDelay = const Duration(milliseconds: 700),
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client;

  /// Emits one map per chunk of [ncodes] (lower-case, as stored in
  /// `NovelMetadata.novelId`): each asked-for ncode mapped to its total
  /// episode count, or to null when it could not be determined. A failed
  /// request fails only its own chunk. [isR18] selects the R18 API, which
  /// serves `novel18.syosetu.com` works.
  ///
  /// A cancellation is observed before each request (and aborts the one in
  /// flight through the token's callbacks set up by the caller) and surfaces
  /// as [CancelledException].
  Stream<Map<String, int?>> fetchEpisodeCounts(
    List<String> ncodes, {
    required bool isR18,
    CancellationToken? cancelToken,
  }) async* {
    final unique = {for (final n in ncodes) n.toLowerCase()}.toList();
    for (var start = 0; start < unique.length; start += chunkSize) {
      cancelToken?.throwIfCancelled();
      if (start > 0) {
        await Future<void>.delayed(requestDelay);
        cancelToken?.throwIfCancelled();
      }
      final end = start + chunkSize < unique.length
          ? start + chunkSize
          : unique.length;
      final chunk = unique.sublist(start, end);
      final found = await _fetchChunk(chunk, isR18: isR18, cancelToken);
      yield {for (final n in chunk) n: found[n]};
    }
  }

  Future<Map<String, int>> _fetchChunk(
    List<String> chunk,
    CancellationToken? cancelToken, {
    required bool isR18,
  }) async {
    final url = Uri.https(_host, isR18 ? _r18Path : _generalPath, {
      'out': 'json',
      'of': 'n-ga',
      'lim': '500',
      'ncode': chunk.join('-'),
    });
    try {
      final response = await _client
          .get(url, headers: const {'User-Agent': _userAgent})
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        _log.warning('Narou API returned HTTP ${response.statusCode}');
        return const {};
      }
      return _parse(utf8.decode(response.bodyBytes), chunk.toSet());
    } catch (e, st) {
      // A cancellation closes the client; report it as such, not as a failure.
      cancelToken?.throwIfCancelled();
      _log.warning('Narou API request failed', e, st);
      return const {};
    }
  }

  static Map<String, int> _parse(String body, Set<String> asked) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException('Narou API response is not a list');
    }
    final result = <String, int>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final ncode = item['ncode'];
      final count = item['general_all_no'];
      if (ncode is! String || count is! int) continue;
      final key = ncode.toLowerCase();
      if (asked.contains(key)) result[key] = count;
    }
    return result;
  }
}
