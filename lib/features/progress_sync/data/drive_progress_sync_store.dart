import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../domain/device_progress.dart';
import '../domain/device_progress_codec.dart';
import 'progress_sync_store.dart';

final _log = Logger('progress_sync');

/// Supplies the OAuth access token for Drive requests.
abstract class AccessTokenSource {
  /// The current access token; [forceRefresh] trades it for a new one after
  /// Drive rejected it.
  Future<String> accessToken({bool forceRefresh = false});
}

/// Remembers the Drive file id of this device's own file between runs, so a
/// write is one request instead of a search and a write.
abstract class DriveFileIdStore {
  Future<String?> read();
  Future<void> write(String? id);
}

class ProgressSyncHttpException implements Exception {
  final int statusCode;
  final String message;

  const ProgressSyncHttpException(this.statusCode, this.message);

  @override
  String toString() => 'ProgressSyncHttpException($statusCode): $message';
}

/// [ProgressSyncStore] on the Drive appDataFolder: a space only this app's
/// Cloud project can see, reached with the `drive.appdata` scope (design D1).
class DriveProgressSyncStore implements ProgressSyncStore {
  static const _filePrefix = 'device-';
  static final _api = Uri.parse('https://www.googleapis.com/drive/v3/files');
  static final _upload = Uri.parse(
    'https://www.googleapis.com/upload/drive/v3/files',
  );

  final http.Client _client;
  final AccessTokenSource _tokens;
  final DriveFileIdStore _fileIds;

  DriveProgressSyncStore({
    required http.Client client,
    required AccessTokenSource tokens,
    required DriveFileIdStore fileIds,
  }) : _client = client,
       _tokens = tokens,
       _fileIds = fileIds;

  static String fileNameFor(String deviceId) => '$_filePrefix$deviceId.json';

  @override
  Future<List<DeviceProgress>> fetchAll() async {
    final files = await _list("name contains '$_filePrefix'");
    final devices = <DeviceProgress>[];
    for (final file in files) {
      final response = await _send(
        () => http.Request(
          'GET',
          _api.replace(
            path: '${_api.path}/${file.id}',
            queryParameters: {'alt': 'media'},
          ),
        ),
      );
      try {
        devices.add(decodeDeviceProgress(utf8.decode(response.bodyBytes)));
      } on FormatException catch (e, st) {
        _log.warning('Skipping unreadable progress file ${file.name}', e, st);
      }
    }
    return devices;
  }

  @override
  Future<void> writeOwn(DeviceProgress own) async {
    final body = encodeDeviceProgress(own);
    final known = await _fileIds.read();
    if (known != null && await _update(known, body)) return;

    final name = fileNameFor(own.deviceId);
    final found = await _list("name = '$name'");
    if (found.isNotEmpty && await _update(found.first.id, body)) {
      await _fileIds.write(found.first.id);
      return;
    }
    await _fileIds.write(await _create(name, body));
  }

  /// Uploads [body] over file [id]; false when that file no longer exists.
  Future<bool> _update(String id, String body) async {
    try {
      await _send(
        () =>
            http.Request(
                'PATCH',
                _upload.replace(
                  path: '${_upload.path}/$id',
                  queryParameters: {'uploadType': 'media'},
                ),
              )
              ..headers['content-type'] = 'application/json; charset=utf-8'
              ..body = body,
      );
      return true;
    } on ProgressSyncHttpException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<String> _create(String name, String body) async {
    const boundary = 'novel_viewer_progress_sync';
    final metadata = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
    });
    final multipart =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$body\r\n'
        '--$boundary--';
    final response = await _send(
      () =>
          http.Request(
              'POST',
              _upload.replace(queryParameters: {'uploadType': 'multipart'}),
            )
            ..headers['content-type'] = 'multipart/related; boundary=$boundary'
            ..body = multipart,
    );
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<List<({String id, String name})>> _list(String query) async {
    final files = <({String id, String name})>[];
    String? pageToken;
    do {
      final response = await _send(
        () => http.Request(
          'GET',
          _api.replace(
            queryParameters: {
              'spaces': 'appDataFolder',
              'q': '$query and trashed = false',
              'fields': 'nextPageToken, files(id, name)',
              'pageSize': '100',
              'pageToken': ?pageToken,
            },
          ),
        ),
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      for (final file in json['files'] as List<dynamic>) {
        final map = file as Map<String, dynamic>;
        files.add((id: map['id'] as String, name: map['name'] as String));
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null);
    return files;
  }

  /// Sends the request [build] makes, retrying once with a fresh token when
  /// Drive answers 401. Throws [ProgressSyncHttpException] for any other
  /// non-2xx answer.
  Future<http.Response> _send(http.Request Function() build) async {
    var response = await _sendWith(build(), await _tokens.accessToken());
    if (response.statusCode == 401) {
      response = await _sendWith(
        build(),
        await _tokens.accessToken(forceRefresh: true),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProgressSyncHttpException(response.statusCode, response.body);
    }
    return response;
  }

  Future<http.Response> _sendWith(http.Request request, String token) async {
    request.headers['authorization'] = 'Bearer $token';
    return http.Response.fromStream(await _client.send(request));
  }
}
