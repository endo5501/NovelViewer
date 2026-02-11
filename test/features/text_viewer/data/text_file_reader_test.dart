import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_viewer/data/text_file_reader.dart';

void main() {
  late Directory tempDir;
  late TextFileReader reader;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('novel_viewer_text_test_');
    reader = TextFileReader();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('readFile', () {
    test('reads UTF-8 text file content', () async {
      final filePath = '${tempDir.path}/test.txt';
      File(filePath).writeAsStringSync('これはテストです。\n二行目のテキスト。');

      final content = await reader.readFile(filePath);

      expect(content, 'これはテストです。\n二行目のテキスト。');
    });

    test('reads empty file', () async {
      final filePath = '${tempDir.path}/empty.txt';
      File(filePath).writeAsStringSync('');

      final content = await reader.readFile(filePath);

      expect(content, '');
    });

    test('reads file with multiple lines', () async {
      final filePath = '${tempDir.path}/multi.txt';
      File(filePath).writeAsStringSync('行1\n行2\n行3\n行4\n行5');

      final content = await reader.readFile(filePath);

      expect(content.split('\n').length, 5);
    });
  });
}
