import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:novel_viewer/features/app_update/domain/update_constants.dart';

class GithubReleaseException implements Exception {
  GithubReleaseException(this.message);
  final String message;
  @override
  String toString() => 'GithubReleaseException: $message';
}

/// Fetches the latest stable release metadata from the GitHub Releases API.
class GithubReleaseClient {
  GithubReleaseClient({
    required http.Client httpClient,
    required String userAgent,
    this.timeout = const Duration(seconds: 10),
  })  : _httpClient = httpClient,
        _userAgent = userAgent;

  final http.Client _httpClient;
  final String _userAgent;
  final Duration timeout;

  Future<ReleaseInfo> fetchLatest() async {
    final uri = Uri.parse(latestReleaseApiUrl());
    http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(timeout);
    } catch (e) {
      throw GithubReleaseException('request failed: $e');
    }

    if (response.statusCode != 200) {
      throw GithubReleaseException(
          'unexpected status ${response.statusCode}');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('expected a JSON object');
      }
      return ReleaseInfo.fromJson(decoded);
    } catch (e) {
      throw GithubReleaseException('failed to parse response: $e');
    }
  }
}
