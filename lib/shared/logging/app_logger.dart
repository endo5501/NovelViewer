import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_log_sink.dart';
import 'log_sink.dart';

typedef DebugSink = void Function(String message);

class AppLogger {
  AppLogger._();

  static StreamSubscription<LogRecord>? _subscription;
  static LogSink? _activeFileSink;
  static DebugSink _printer = _defaultDebugPrint;
  static bool _useFileSink = false;

  static Future<void> initialize({
    bool? debug,
    DebugSink? debugSink,
    LogSink? fileSink,
  }) async {
    await resetForTest();

    final isDebug = debug ?? kDebugMode;
    _printer = debugSink ?? _defaultDebugPrint;
    Logger.root.level = isDebug ? Level.ALL : Level.INFO;

    // Attach dispatcher synchronously so records emitted during the file-sink
    // setup window below still reach _printer instead of being dropped.
    _subscription = Logger.root.onRecord.listen(_dispatch);

    if (isDebug) return;

    try {
      final sink = fileSink ?? await _createDefaultFileSink();
      await sink.initialize();
      _activeFileSink = sink;
      _useFileSink = true;
    } catch (_) {
      _activeFileSink = null;
      _useFileSink = false;
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    await _subscription?.cancel();
    _subscription = null;
    await _activeFileSink?.close();
    _activeFileSink = null;
    _useFileSink = false;
    _printer = _defaultDebugPrint;
    Logger.root.level = Level.INFO;
  }

  static void _dispatch(LogRecord record) {
    final sink = _activeFileSink;
    if (!_useFileSink || sink == null) {
      _emitToPrinter(record);
      return;
    }
    try {
      sink.write(record);
    } catch (_) {
      _emitToPrinter(record);
    }
  }

  static void _emitToPrinter(LogRecord record) {
    _printer('[${record.level.name}] ${record.loggerName}: ${record.message}');
  }

  static Future<LogSink> _createDefaultFileSink() async {
    final supportDir = await getApplicationSupportDirectory();
    return FileLogSink(dirPath: p.join(supportDir.path, 'logs'));
  }

  static void _defaultDebugPrint(String message) => debugPrint(message);
}
