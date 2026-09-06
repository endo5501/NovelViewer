import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_position_writer.dart';
import 'package:novel_viewer/features/reading_progress/data/reading_progress_repository.dart';
import 'package:novel_viewer/features/reading_progress/domain/reading_progress.dart';
import 'package:novel_viewer/features/reading_progress/providers/reading_progress_providers.dart';
import 'package:novel_viewer/shared/utils/novel_id_resolver.dart';

final readingPositionWriterProvider = Provider<ReadingPositionWriter>((ref) {
  // Resolve the repository on the first actual write rather than here. The
  // writer is constructed eagerly at app start (see NovelViewerApp), and
  // touching the repository at build time would pull in novelDatabaseProvider
  // before startup has overridden it -- making the whole widget tree
  // unmountable without a database. Memoized so later writes reuse it and the
  // dispose-time flush still works once a write has happened.
  ReadingProgressRepository? repository;
  final writer = ReadingPositionWriter(
    save: (snapshot) {
      final ReadingProgressRepository target =
          repository ?? ref.read(readingProgressRepositoryProvider);
      repository = target;
      return target.savePosition(
        novelId: snapshot.novelId,
        fileName: snapshot.fileName,
        bodyOffset: snapshot.offset,
        bodyHash: snapshot.hash,
      );
    },
  );
  ref.onDispose(writer.dispose);
  return writer;
});

final readingPositionForFileProvider = FutureProvider.autoDispose
    .family<ReadingProgress?, String>((ref, path) async {
      ref.watch(selectedFileProvider);
      try {
        final root = ref.read(libraryPathProvider);
        if (root == null) return null;
        final novels = await ref.watch(allNovelsProvider.future);
        if (!ref.mounted) return null;
        final id = resolveNovelId(root, path, {
          for (final n in novels) n.folderName,
        });
        if (id == null) return null;
        await ref.read(readingPositionWriterProvider).flush();
        if (!ref.mounted) return null;
        final saved = await ref
            .read(readingProgressRepositoryProvider)
            .findByNovelId(id);
        if (saved != null && p.equals(saved.fileName, p.basename(path))) {
          return saved;
        }
        return ReadingProgress(
          novelId: id,
          fileName: p.basename(path),
          updatedAt: DateTime.now(),
        );
      } catch (e, st) {
        Logger(
          'reading_progress',
        ).warning('Failed to load reading position', e, st);
        return null;
      }
    });

final readingPositionLifecycleProvider = Provider<void>((ref) {
  final observer = _PositionLifecycle(ref.read(readingPositionWriterProvider));
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

class _PositionLifecycle extends WidgetsBindingObserver {
  _PositionLifecycle(this.writer);
  final ReadingPositionWriter writer;

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await writer.flush();
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(writer.flush());
  }
}
