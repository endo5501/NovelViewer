import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/episode_navigation/domain/file_entry_start_intent.dart';

/// Holds a one-shot hint indicating where the text viewer should start the
/// next file it renders. Producers (navigation actions) `set` a value just
/// before switching `selectedFileProvider`; consumers (viewers) read and then
/// `clear` it after applying the initial position.
class PendingFileEntryIntentNotifier extends Notifier<FileEntryStartIntent?> {
  @override
  FileEntryStartIntent? build() => null;

  void set(FileEntryStartIntent intent) => state = intent;

  void clear() => state = null;
}

final pendingFileEntryIntentProvider =
    NotifierProvider<PendingFileEntryIntentNotifier, FileEntryStartIntent?>(
        PendingFileEntryIntentNotifier.new);
