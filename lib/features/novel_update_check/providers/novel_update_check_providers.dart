import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/novel_update_check/data/narou_api_client.dart';
import 'package:novel_viewer/features/novel_update_check/data/novel_update_checker.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

final _log = Logger('novel_update_check');

enum UpdateCheckStatus { idle, checking, completed, cancelled, error }

class UpdateCheckState {
  final UpdateCheckStatus status;

  /// Target works checked so far, and how many there are.
  final int done;
  final int total;

  /// Set once [status] is [UpdateCheckStatus.completed].
  final UpdateCheckSummary? summary;

  const UpdateCheckState({
    this.status = UpdateCheckStatus.idle,
    this.done = 0,
    this.total = 0,
    this.summary,
  });
}

/// Builds the HTTP client one check runs on. A fresh client per check, since
/// a cancellation closes it to abort the request in flight.
final updateCheckClientFactoryProvider = Provider<http.Client Function()>(
  (ref) => http.Client.new,
);

/// Builds the checker for one run on top of that run's [http.Client].
final novelUpdateCheckerFactoryProvider =
    Provider<NovelUpdateChecker Function(http.Client client)>(
      (ref) =>
          (client) => NovelUpdateChecker(
            repository: ref.read(novelRepositoryProvider),
            downloadService: DownloadService(client: client),
            narouApi: NarouApiClient(client: client),
          ),
    );

final novelUpdateCheckProvider =
    NotifierProvider<NovelUpdateCheckNotifier, UpdateCheckState>(
      NovelUpdateCheckNotifier.new,
    );

/// Runs the library-wide update check (novel-update-check) and exposes its
/// progress to the progress dialog. One check at a time; the novel list is
/// reloaded however the check ends, so badges pick up what was recorded.
class NovelUpdateCheckNotifier extends Notifier<UpdateCheckState> {
  CancellationToken? _cancelToken;

  @override
  UpdateCheckState build() => const UpdateCheckState();

  Future<void> start() async {
    if (state.status == UpdateCheckStatus.checking) return;
    final token = CancellationToken();
    _cancelToken = token;
    state = const UpdateCheckState(status: UpdateCheckStatus.checking);

    final client = ref.read(updateCheckClientFactoryProvider)();
    token.onCancel(client.close);
    try {
      final novels = await ref.read(allNovelsProvider.future);
      final summary = await ref
          .read(novelUpdateCheckerFactoryProvider)(client)
          .run(
            novels,
            cancelToken: token,
            onProgress: (done, total) {
              state = UpdateCheckState(
                status: UpdateCheckStatus.checking,
                done: done,
                total: total,
              );
            },
          );
      state = UpdateCheckState(
        status: UpdateCheckStatus.completed,
        done: state.total,
        total: state.total,
        summary: summary,
      );
    } on CancelledException {
      state = UpdateCheckState(
        status: UpdateCheckStatus.cancelled,
        done: state.done,
        total: state.total,
      );
    } catch (e, st) {
      _log.warning('Update check failed', e, st);
      state = const UpdateCheckState(status: UpdateCheckStatus.error);
    } finally {
      _cancelToken = null;
      client.close();
      ref.invalidate(allNovelsProvider);
    }
  }

  /// Asks the running check to stop before its next request.
  void cancel() => _cancelToken?.cancel();

  /// Back to idle once the dialog showing a finished check is closed.
  void reset() {
    if (state.status == UpdateCheckStatus.checking) return;
    state = const UpdateCheckState();
  }
}
