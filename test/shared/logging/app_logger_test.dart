import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:novel_viewer/shared/logging/app_logger.dart';
import 'package:novel_viewer/shared/logging/log_sink.dart';

class _RecordingSink implements LogSink {
  final List<LogRecord> records = [];

  @override
  Future<void> initialize() async {}

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
}

class _ThrowingSink implements LogSink {
  @override
  Future<void> initialize() async {
    throw Exception('path_provider unavailable');
  }

  @override
  void write(LogRecord record) {}

  @override
  Future<void> close() async {}
}

class _ControllableSink implements LogSink {
  final initGate = Completer<void>();
  final List<LogRecord> records = [];

  @override
  Future<void> initialize() => initGate.future;

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
}

void main() {
  setUp(() async {
    await AppLogger.resetForTest();
  });

  tearDown(() async {
    await AppLogger.resetForTest();
  });

  group('AppLogger.initialize', () {
    test('sets root level to Level.ALL in debug mode', () async {
      await AppLogger.initialize(debug: true);
      expect(Logger.root.level, Level.ALL);
    });

    test('sets root level to Level.INFO in release mode', () async {
      final sink = _RecordingSink();
      await AppLogger.initialize(debug: false, fileSink: sink);
      expect(Logger.root.level, Level.INFO);
    });

    test(
        'routes records to debugPrint sink with [LEVEL] name: message format in debug mode',
        () async {
      final printed = <String>[];
      await AppLogger.initialize(
        debug: true,
        debugSink: printed.add,
      );

      Logger('foo').info('bar');
      await Future<void>.delayed(Duration.zero);

      expect(printed, contains('[INFO] foo: bar'));
    });

    test('routes records to file sink in release mode', () async {
      final sink = _RecordingSink();
      await AppLogger.initialize(debug: false, fileSink: sink);

      Logger('foo').info('bar');
      await Future<void>.delayed(Duration.zero);

      expect(sink.records, hasLength(1));
      expect(sink.records.single.loggerName, 'foo');
      expect(sink.records.single.message, 'bar');
      expect(sink.records.single.level, Level.INFO);
    });

    test('drops Level.FINE records in release mode', () async {
      final sink = _RecordingSink();
      await AppLogger.initialize(debug: false, fileSink: sink);

      Logger('foo').fine('debug detail');
      await Future<void>.delayed(Duration.zero);

      expect(sink.records, isEmpty);
    });

    test(
        'does not throw and does not block startup when file sink initialization fails',
        () async {
      final sink = _ThrowingSink();

      await expectLater(
        AppLogger.initialize(debug: false, fileSink: sink),
        completes,
      );
    });

    test(
        'records emitted during async sink setup reach the debug sink, not the file sink',
        () async {
      final printed = <String>[];
      final sink = _ControllableSink();

      final initFuture = AppLogger.initialize(
        debug: false,
        fileSink: sink,
        debugSink: printed.add,
      );

      // Yield once so initialize() reaches `await sink.initialize()` and the
      // dispatcher listener is attached but _useFileSink is still false.
      await Future<void>.delayed(Duration.zero);

      Logger('feature').info('mid-init');
      await Future<void>.delayed(Duration.zero);

      expect(printed.any((m) => m.contains('mid-init')), isTrue,
          reason: 'record during async setup should reach debug sink');
      expect(sink.records, isEmpty,
          reason: 'file sink must not receive records before it is ready');

      sink.initGate.complete();
      await initFuture;
    });

    test(
        'still routes records to debugPrint fallback when release sink fails to initialize',
        () async {
      final printed = <String>[];

      await AppLogger.initialize(
        debug: false,
        fileSink: _ThrowingSink(),
        debugSink: printed.add,
      );

      Logger('foo').info('bar');
      await Future<void>.delayed(Duration.zero);

      expect(printed, isNotEmpty);
      expect(printed.first, contains('foo'));
      expect(printed.first, contains('bar'));
    });
  });
}
