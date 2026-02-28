import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/novel_metadata_db/providers/novel_metadata_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_database.dart';
import 'package:novel_viewer/features/tts/data/tts_audio_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);

  @override
  String? build() => _initialValue;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DirectoryContents ttsStatuses field', () {
    test('defaults to empty map', () {
      const contents = DirectoryContents(files: [], subdirectories: []);
      expect(contents.ttsStatuses, isEmpty);
    });

    test('empty() factory returns empty ttsStatuses', () {
      final contents = DirectoryContents.empty();
      expect(contents.ttsStatuses, isEmpty);
    });

    test('accepts ttsStatuses in constructor', () {
      const contents = DirectoryContents(
        files: [],
        subdirectories: [],
        ttsStatuses: {
          '001.txt': TtsEpisodeStatus.completed,
          '002.txt': TtsEpisodeStatus.partial,
        },
      );
      expect(contents.ttsStatuses, hasLength(2));
      expect(contents.ttsStatuses['001.txt'], TtsEpisodeStatus.completed);
      expect(contents.ttsStatuses['002.txt'], TtsEpisodeStatus.partial);
    });
  });

  group('directoryContentsProvider TTS status integration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dir_contents_tts_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('includes ttsStatuses when tts_audio.db exists', () async {
      // Create test text files
      File('${tempDir.path}/0001_chapter1.txt').writeAsStringSync('content1');
      File('${tempDir.path}/0002_chapter2.txt').writeAsStringSync('content2');

      // Create TTS database with episode records
      final ttsDb = TtsAudioDatabase(tempDir.path);
      final repo = TtsAudioRepository(ttsDb);
      await repo.createEpisode(
        fileName: '0001_chapter1.txt',
        sampleRate: 24000,
        status: 'completed',
      );
      await repo.createEpisode(
        fileName: '0002_chapter2.txt',
        sampleRate: 24000,
        status: 'partial',
      );
      await ttsDb.close();

      final container = ProviderContainer(
        overrides: [
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier(tempDir.path);
          }),
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);

      final contents =
          await container.read(directoryContentsProvider.future);

      expect(contents.ttsStatuses, hasLength(2));
      expect(contents.ttsStatuses['0001_chapter1.txt'],
          TtsEpisodeStatus.completed);
      expect(contents.ttsStatuses['0002_chapter2.txt'],
          TtsEpisodeStatus.partial);
    });

    test('returns empty ttsStatuses when no tts_audio.db exists', () async {
      // Create test text files without TTS database
      File('${tempDir.path}/0001_chapter1.txt').writeAsStringSync('content1');

      final container = ProviderContainer(
        overrides: [
          currentDirectoryProvider.overrideWith(() {
            return _TestCurrentDirectoryNotifier(tempDir.path);
          }),
          libraryPathProvider.overrideWithValue('/library'),
          allNovelsProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);

      final contents =
          await container.read(directoryContentsProvider.future);

      expect(contents.ttsStatuses, isEmpty);
    });
  });
}
