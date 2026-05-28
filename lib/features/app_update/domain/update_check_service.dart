import 'package:logging/logging.dart';
import 'package:novel_viewer/features/app_update/data/github_release_client.dart';
import 'package:novel_viewer/features/app_update/data/release_info.dart';
import 'package:novel_viewer/features/app_update/data/update_preferences.dart';
import 'package:novel_viewer/features/app_update/domain/update_constants.dart';
import 'package:novel_viewer/features/app_update/domain/version_comparator.dart';

sealed class UpdateStatus {
  const UpdateStatus();
}

/// Auto check was not performed (debug build, disabled, or rate limited).
class UpdateSkipped extends UpdateStatus {
  const UpdateSkipped(this.reason);
  final String reason;
}

class UpdateNotAvailable extends UpdateStatus {
  const UpdateNotAvailable();
}

class UpdateAvailable extends UpdateStatus {
  const UpdateAvailable(this.release);
  final ReleaseInfo release;
}

class UpdateCheckError extends UpdateStatus {
  const UpdateCheckError(this.message);
  final String message;
}

class UpdateCheckService {
  UpdateCheckService({
    required GithubReleaseClient releaseClient,
    required UpdatePreferences preferences,
    required String currentVersion,
    bool isDebug = false,
    DateTime Function()? now,
  })  : _releaseClient = releaseClient,
        _preferences = preferences,
        _currentVersion = currentVersion,
        _isDebug = isDebug,
        _now = now ?? DateTime.now;

  static const _minInterval = Duration(hours: 24);
  static final _log = Logger('app_update.check');

  final GithubReleaseClient _releaseClient;
  final UpdatePreferences _preferences;
  final String _currentVersion;
  final bool _isDebug;
  final DateTime Function() _now;

  /// Checks GitHub for a newer release.
  ///
  /// Auto checks ([manual] = false) are skipped in debug builds, when the user
  /// disabled auto-check, or within 24h of the last check, and they honor the
  /// snoozed ("Later") version. Manual checks ignore all of those.
  Future<UpdateStatus> check({bool manual = false}) async {
    if (!manual) {
      if (_isDebug) return const UpdateSkipped('debug build');
      if (!_preferences.autoCheckEnabled) {
        return const UpdateSkipped('auto-check disabled');
      }
      final last = _preferences.lastCheckAt;
      if (last != null && _now().toUtc().difference(last) < _minInterval) {
        return const UpdateSkipped('checked within the last 24h');
      }
    }

    // Record the attempt time before fetching so a failing/offline check still
    // throttles the next auto check (otherwise every launch re-hits the API and
    // can trip GitHub's unauthenticated rate limit).
    await _preferences.setLastCheckAt(_now().toUtc());

    ReleaseInfo release;
    try {
      release = await _releaseClient.fetchLatest();
    } catch (e) {
      _log.warning('update check failed', e);
      return UpdateCheckError('$e');
    }

    if (!isNewer(current: _currentVersion, tagName: release.tagName)) {
      return const UpdateNotAvailable();
    }

    if (!manual) {
      final dismissed = _preferences.dismissedVersion;
      if (dismissed == normalizeReleaseVersion(release.tagName)) {
        return const UpdateNotAvailable();
      }
    }

    return UpdateAvailable(release);
  }
}
