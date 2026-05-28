import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/app_update/data/distribution_detector.dart';
import 'package:novel_viewer/features/app_update/data/github_release_client.dart';
import 'package:novel_viewer/features/app_update/data/installer_downloader.dart';
import 'package:novel_viewer/features/app_update/data/installer_updater.dart';
import 'package:novel_viewer/features/app_update/data/installer_verifier.dart';
import 'package:novel_viewer/features/app_update/data/process_starter.dart';
import 'package:novel_viewer/features/app_update/data/update_preferences.dart';
import 'package:novel_viewer/features/app_update/domain/distribution_type.dart';
import 'package:novel_viewer/features/app_update/domain/update_check_service.dart';
import 'package:novel_viewer/features/app_update/domain/update_constants.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Overridden in ProviderScope with the value resolved at startup.
final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final updatePreferencesProvider = Provider<UpdatePreferences>((ref) {
  return UpdatePreferences(ref.watch(sharedPreferencesProvider));
});

final distributionTypeProvider = Provider<DistributionType>((ref) {
  return DistributionDetector().detect();
});

final githubReleaseClientProvider = Provider<GithubReleaseClient>((ref) {
  final info = ref.watch(packageInfoProvider);
  return GithubReleaseClient(
    httpClient: ref.watch(httpClientProvider),
    userAgent: userAgentFor(info.version),
  );
});

final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  final info = ref.watch(packageInfoProvider);
  return UpdateCheckService(
    releaseClient: ref.watch(githubReleaseClientProvider),
    preferences: ref.watch(updatePreferencesProvider),
    currentVersion: info.version,
    isDebug: kDebugMode,
  );
});

final installerUpdaterProvider = Provider<InstallerUpdater>((ref) {
  final info = ref.watch(packageInfoProvider);
  return InstallerUpdater(
    downloader: HttpInstallerDownloader(
      httpClient: ref.watch(httpClientProvider),
      userAgent: userAgentFor(info.version),
    ),
    verifier: const InstallerVerifier(),
    processStarter: const Win32ProcessStarter(),
  );
});

/// Holds the latest update-check result that drives the AppBar badge and dialog.
final updateStatusProvider =
    NotifierProvider<UpdateStatusNotifier, UpdateStatus>(
  UpdateStatusNotifier.new,
);

class UpdateStatusNotifier extends Notifier<UpdateStatus> {
  @override
  UpdateStatus build() => const UpdateNotAvailable();

  Future<UpdateStatus> check({bool manual = false}) async {
    final service = ref.read(updateCheckServiceProvider);
    final result = await service.check(manual: manual);
    state = result;
    return result;
  }

  /// Records the "Later" choice for the currently-available version so it is
  /// not surfaced again until a newer version appears.
  Future<void> snooze() async {
    final current = state;
    if (current is! UpdateAvailable) return;
    final normalized = normalizeReleaseVersion(current.release.tagName);
    await ref.read(updatePreferencesProvider).setDismissedVersion(normalized);
    state = const UpdateNotAvailable();
  }
}

/// Convenience view: the available release, or null when none/suppressed.
final updateAvailableProvider = Provider<UpdateAvailable?>((ref) {
  final status = ref.watch(updateStatusProvider);
  return status is UpdateAvailable ? status : null;
});
