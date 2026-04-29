import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/shared/logging/file_log_sink.dart';

LogRecord _record(String message) => LogRecord(
      Level.INFO,
      message,
      'test',
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('file_log_sink_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FileLogSink rotation', () {
    test(
        'rotates app.log to app.log.1 and creates a fresh app.log when threshold is exceeded',
        () async {
      final sink = FileLogSink(dirPath: tempDir.path, maxBytes: 64);
      await sink.initialize();

      // Each formatted line is well over 64 bytes (timestamp + level + name + msg).
      // First write goes to fresh app.log; second write triggers rotation.
      sink.write(_record('first-record'));
      sink.write(_record('after-rotation'));
      await sink.close();

      final activeLog = File('${tempDir.path}/app.log');
      final rotated1 = File('${tempDir.path}/app.log.1');

      expect(activeLog.existsSync(), isTrue);
      expect(rotated1.existsSync(), isTrue);
      expect(activeLog.readAsStringSync(), contains('after-rotation'));
      expect(rotated1.readAsStringSync(), contains('first-record'));
      expect(activeLog.readAsStringSync(), isNot(contains('first-record')));
    });

    test(
        'shifts app.log.1 to app.log.2 and app.log to app.log.1 when both exist on rotation',
        () async {
      final sink = FileLogSink(dirPath: tempDir.path, maxBytes: 64);
      await sink.initialize();

      // After rotation 1: app.log.1 = [gen-1], app.log = [gen-2]
      sink.write(_record('gen-1'));
      sink.write(_record('gen-2'));
      // Rotation 2: shifts .1 -> .2, app.log -> .1, app.log = [gen-3]
      sink.write(_record('gen-3'));
      await sink.close();

      final activeLog = File('${tempDir.path}/app.log');
      final rotated1 = File('${tempDir.path}/app.log.1');
      final rotated2 = File('${tempDir.path}/app.log.2');

      expect(activeLog.existsSync(), isTrue);
      expect(rotated1.existsSync(), isTrue);
      expect(rotated2.existsSync(), isTrue);

      expect(activeLog.readAsStringSync(), contains('gen-3'));
      expect(rotated1.readAsStringSync(), contains('gen-2'));
      expect(rotated2.readAsStringSync(), contains('gen-1'));
    });

    test(
        'caps rotation at three generations: app.log.2 is overwritten and no app.log.3 is created',
        () async {
      final sink = FileLogSink(dirPath: tempDir.path, maxBytes: 64);
      await sink.initialize();

      // After 3 rotations (4 writes that each exceed threshold):
      //   active app.log = [gen-4]
      //   app.log.1      = [gen-3]   (was active, shifted)
      //   app.log.2      = [gen-2]   (was .1, shifted; original .2 = [gen-1] dropped)
      //   app.log.3      = NEVER CREATED
      sink.write(_record('gen-1'));
      sink.write(_record('gen-2'));
      sink.write(_record('gen-3'));
      sink.write(_record('gen-4'));
      await sink.close();

      final activeLog = File('${tempDir.path}/app.log');
      final rotated1 = File('${tempDir.path}/app.log.1');
      final rotated2 = File('${tempDir.path}/app.log.2');
      final rotated3 = File('${tempDir.path}/app.log.3');

      expect(rotated3.existsSync(), isFalse,
          reason: 'no app.log.3 should ever be created');
      expect(activeLog.readAsStringSync(), contains('gen-4'));
      expect(rotated1.readAsStringSync(), contains('gen-3'));
      expect(rotated2.readAsStringSync(), contains('gen-2'));
      // Earliest generation gen-1 must have been dropped.
      expect(rotated2.readAsStringSync(), isNot(contains('gen-1')));
    });
  });

  group('FileLogSink format', () {
    test('writes one tab-delimited line per record', () async {
      final sink = FileLogSink(dirPath: tempDir.path);
      await sink.initialize();
      sink.write(LogRecord(Level.INFO, 'hello world', 'feature.sub'));
      await sink.close();

      final content =
          File('${tempDir.path}/app.log').readAsStringSync().trimRight();
      final fields = content.split('\t');
      expect(fields, hasLength(4));
      expect(fields[1], 'INFO');
      expect(fields[2], 'feature.sub');
      expect(fields[3], 'hello world');
    });

    test(
        'escapes carriage return, newline, tab, and backslash so a record '
        'never spans multiple lines or breaks tab framing', () async {
      final sink = FileLogSink(dirPath: tempDir.path);
      await sink.initialize();
      sink.write(LogRecord(Level.INFO, 'a\rb\nc\td\\e', 'test'));
      await sink.close();

      final content = File('${tempDir.path}/app.log').readAsStringSync();
      // Exactly one record line.
      expect(content.split('\n').where((s) => s.isNotEmpty), hasLength(1));
      final fields = content.trimRight().split('\t');
      expect(fields, hasLength(4));
      expect(fields[3], r'a\rb\nc\td\\e');
    });
  });
}
