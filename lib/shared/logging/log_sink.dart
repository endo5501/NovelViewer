import 'package:logging/logging.dart';

abstract class LogSink {
  Future<void> initialize();

  void write(LogRecord record);

  Future<void> close();
}
