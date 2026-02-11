import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_search/providers/text_search_providers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('search_provider_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createFile(String name, String content) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(content);
  }

  group('searchQueryProvider', () {
    test('initial value is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(searchQueryProvider), isNull);
    });

    test('can set search query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).setQuery('太郎');

      expect(container.read(searchQueryProvider), '太郎');
    });

    test('can clear search query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).setQuery('太郎');
      container.read(searchQueryProvider.notifier).setQuery(null);

      expect(container.read(searchQueryProvider), isNull);
    });
  });

  group('searchResultsProvider', () {
    test('returns null when query is null', () async {
      final container = ProviderContainer(
        overrides: [
          currentDirectoryProvider.overrideWith(() {
            final notifier = CurrentDirectoryNotifier(tempDir.path);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(searchResultsProvider.future);

      expect(result, isNull);
    });

    test('returns search results when query and directory are set', () async {
      await createFile('001.txt', '太郎が走った');

      final container = ProviderContainer(
        overrides: [
          currentDirectoryProvider.overrideWith(() {
            return CurrentDirectoryNotifier(tempDir.path);
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).setQuery('太郎');

      final result = await container.read(searchResultsProvider.future);

      expect(result, isNotNull);
      expect(result!, hasLength(1));
      expect(result[0].fileName, '001.txt');
    });

    test('returns null when directory is not set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).setQuery('太郎');

      final result = await container.read(searchResultsProvider.future);

      expect(result, isNull);
    });

    test('returns empty list when no matches found', () async {
      await createFile('001.txt', '花子が走った');

      final container = ProviderContainer(
        overrides: [
          currentDirectoryProvider.overrideWith(() {
            return CurrentDirectoryNotifier(tempDir.path);
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).setQuery('太郎');

      final result = await container.read(searchResultsProvider.future);

      expect(result, isNotNull);
      expect(result!, isEmpty);
    });
  });
}
