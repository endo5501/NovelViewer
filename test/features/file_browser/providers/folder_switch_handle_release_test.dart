import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_audio_database_provider.dart';
import 'package:novel_viewer/shared/database/folder_db_key.dart';
import 'package:novel_viewer/shared/database/novel_data_database_provider.dart';

class _TestCurrentDirectoryNotifier extends CurrentDirectoryNotifier {
  final String? _initialValue;
  _TestCurrentDirectoryNotifier(this._initialValue);
  @override
  String? build() => _initialValue;
}

void main() {
  // A path spelled with a redundant `..` segment so its raw form differs from
  // its normalized (folderDbKey) form on every platform. The release side must
  // key by the normalized form to reach a handle opened under it.
  const rawOld = '/library/narou_n1/../narou_n1';

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        currentDirectoryProvider
            .overrideWith(() => _TestCurrentDirectoryNotifier(rawOld)),
      ]);

  group('folder switch releases per-folder handles via the normalized key', () {
    test('tts_audio handle keyed by folderDbKey is invalidated on switch', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final key = folderDbKey(rawOld);
      final before = container.read(ttsAudioDatabaseProvider(key));

      container.read(currentDirectoryProvider.notifier).setDirectory('/other');

      final after = container.read(ttsAudioDatabaseProvider(key));
      expect(identical(before, after), isFalse,
          reason: 'switching away SHALL invalidate the handle keyed by the '
              'normalized old path, not the raw spelling');
    });

    test('tts_dictionary handle keyed by folderDbKey is invalidated on switch',
        () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final key = folderDbKey(rawOld);
      final before = container.read(ttsDictionaryDatabaseProvider(key));

      container.read(currentDirectoryProvider.notifier).setDirectory('/other');

      final after = container.read(ttsDictionaryDatabaseProvider(key));
      expect(identical(before, after), isFalse,
          reason: 'switching away SHALL invalidate the handle keyed by the '
              'normalized old path, not the raw spelling');
    });

    test('novel_data handle keyed by folderDbKey is invalidated on switch', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final key = folderDbKey(rawOld);
      final before = container.read(novelDataDatabaseProvider(key));

      container.read(currentDirectoryProvider.notifier).setDirectory('/other');

      final after = container.read(novelDataDatabaseProvider(key));
      expect(identical(before, after), isFalse,
          reason: 'switching away SHALL invalidate the novel_data handle keyed '
              'by the normalized old path');
    });
  });
}
