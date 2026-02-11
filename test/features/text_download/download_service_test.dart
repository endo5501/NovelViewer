import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/download_service.dart';

void main() {
  group('safeName', () {
    test('replaces invalid file name characters with underscore', () {
      expect(safeName('file/name'), 'file_name');
      expect(safeName('file\\name'), 'file_name');
      expect(safeName('file:name'), 'file_name');
      expect(safeName('file*name'), 'file_name');
      expect(safeName('file?name'), 'file_name');
      expect(safeName('file"name'), 'file_name');
      expect(safeName('file<name'), 'file_name');
      expect(safeName('file>name'), 'file_name');
      expect(safeName('file|name'), 'file_name');
    });

    test('normalizes multiple spaces to single space', () {
      expect(safeName('hello   world'), 'hello world');
    });

    test('trims whitespace', () {
      expect(safeName('  hello  '), 'hello');
    });

    test('keeps valid characters including Japanese', () {
      expect(safeName('第一話 プロローグ'), '第一話 プロローグ');
    });
  });

  group('formatEpisodeFileName', () {
    test('formats with zero-padded index and title', () {
      expect(formatEpisodeFileName(1, 'プロローグ', 100), '001_プロローグ.txt');
      expect(formatEpisodeFileName(10, '第十話', 100), '010_第十話.txt');
      expect(formatEpisodeFileName(100, '最終話', 100), '100_最終話.txt');
    });

    test('pads based on total episode count', () {
      expect(formatEpisodeFileName(1, 'test', 9), '1_test.txt');
      expect(formatEpisodeFileName(1, 'test', 10), '01_test.txt');
      expect(formatEpisodeFileName(1, 'test', 1000), '0001_test.txt');
    });

    test('sanitizes title in file name', () {
      expect(
        formatEpisodeFileName(1, '第一話/始まり', 10),
        '01_第一話_始まり.txt',
      );
    });
  });

  group('DownloadService', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('novel_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('createNovelDirectory creates directory with novel title', () async {
      final service = DownloadService();
      final dir = await service.createNovelDirectory(
        tempDir.path,
        'テスト小説',
      );

      expect(dir.existsSync(), isTrue);
      expect(dir.path, contains('テスト小説'));
    });

    test('createNovelDirectory sanitizes directory name', () async {
      final service = DownloadService();
      final dir = await service.createNovelDirectory(
        tempDir.path,
        'テスト/小説',
      );

      expect(dir.existsSync(), isTrue);
      expect(dir.path, contains('テスト_小説'));
    });

    test('saveEpisode writes text file with correct name', () async {
      final service = DownloadService();
      final dir = await service.createNovelDirectory(
        tempDir.path,
        'テスト小説',
      );

      await service.saveEpisode(
        directory: dir,
        index: 1,
        title: 'プロローグ',
        content: 'テスト本文です。',
        totalEpisodes: 10,
      );

      final file = File('${dir.path}/01_プロローグ.txt');
      expect(file.existsSync(), isTrue);
      expect(await file.readAsString(), 'テスト本文です。');
    });
  });
}
