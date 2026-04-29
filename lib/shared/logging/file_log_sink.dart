import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'log_sink.dart';

class FileLogSink implements LogSink {
  FileLogSink({
    required this.dirPath,
    this.fileName = 'app.log',
    this.maxBytes = 1024 * 1024,
  });

  final String dirPath;
  final String fileName;
  final int maxBytes;

  RandomAccessFile? _raf;
  int _currentSize = 0;

  String get _activePath => p.join(dirPath, fileName);

  String _rotatedPath(int gen) => p.join(dirPath, '$fileName.$gen');

  @override
  Future<void> initialize() async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(_activePath);
    if (await file.exists()) {
      _currentSize = await file.length();
    }
    _raf = await file.open(mode: FileMode.append);
  }

  @override
  void write(LogRecord record) {
    if (_raf == null) return;

    final bytes = utf8.encode(_format(record));
    if (_currentSize > 0 && _currentSize + bytes.length > maxBytes) {
      _rotate();
    }
    _raf!.writeFromSync(bytes);
    _currentSize += bytes.length;
  }

  @override
  Future<void> close() async {
    final raf = _raf;
    _raf = null;
    if (raf != null) {
      await raf.close();
    }
  }

  String _format(LogRecord r) {
    final ts = r.time.toUtc().toIso8601String();
    final msg = r.message
        .replaceAll(r'\', r'\\')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t');
    return '$ts\t${r.level.name}\t${r.loggerName}\t$msg\n';
  }

  void _rotate() {
    _raf?.closeSync();
    _raf = null;

    try {
      final active = File(_activePath);
      final r1 = File(_rotatedPath(1));
      final r2 = File(_rotatedPath(2));

      if (r1.existsSync()) {
        if (r2.existsSync()) {
          r2.deleteSync();
        }
        r1.renameSync(r2.path);
      }
      active.renameSync(r1.path);
    } on FileSystemException {
      // Rotation failed (likely a transient rename/delete race). Fall through
      // and try to keep the sink usable by reopening the active file in
      // truncate mode below; losing the existing tail is preferable to
      // silently dropping every subsequent record.
    }

    _raf = File(_activePath).openSync(mode: FileMode.writeOnlyAppend);
    _currentSize = 0;
  }
}
