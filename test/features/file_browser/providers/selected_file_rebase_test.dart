import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';

const _before = FileEntry(name: '0001.txt', path: '/library/連載中/0001.txt');
const _after = FileEntry(name: '0001.txt', path: '/library/完結済み/0001.txt');

void main() {
  group('SelectedFileNotifier.rebase', () {
    test('パスを付け替える', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(selectedFileProvider.notifier).selectFile(_before);

      container.read(selectedFileProvider.notifier).rebase(_after);

      expect(container.read(selectedFileProvider), _after);
    });

    test('ファイルを開く要求として数えない', () {
      // The shell closes the drawer on a file-open request. Renaming a folder
      // opens nothing, so a reader who renamed one in the drawer must not
      // have it shut on them.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(selectedFileProvider.notifier).selectFile(_before);
      final afterSelect = container.read(fileOpenRequestProvider);

      container.read(selectedFileProvider.notifier).rebase(_after);

      expect(container.read(fileOpenRequestProvider), afterSelect);
    });

    test('選択して開く操作は従来どおり要求を数える', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final before = container.read(fileOpenRequestProvider);

      container.read(selectedFileProvider.notifier).selectFile(_before);

      expect(container.read(fileOpenRequestProvider), greaterThan(before));
    });
  });
}
