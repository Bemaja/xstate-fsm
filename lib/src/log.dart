import 'package:logging/logging.dart';

typedef LogMessage = String Function();

typedef LogOnRecord = void Function(LogRecord record);

typedef LogFormatter = void Function(LogLine line);

class LogObject {
  final dynamic observed;
  final LogMessage message;
  final Map<String, dynamic> data;

  const LogObject(this.observed, this.message, this.data);

  @override
  String toString() => message();
}

class LogLine {
  final LogRecord record;
  final dynamic observed;

  const LogLine({this.record, this.observed});
}

class Log {
  const Log();

  Logger getLogger(dynamic observed) {
    return Logger(observed.runtimeType.toString());
  }

  void fine(dynamic observed, LogMessage message, {Map<String, dynamic> data}) {
    if (Logger.root.isLoggable(Level.FINE)) {
      getLogger(observed).fine(() => LogObject(observed, message, data));
    }
  }

  void finer(dynamic observed, LogMessage message,
      {Map<String, dynamic> data}) {
    if (Logger.root.isLoggable(Level.FINER)) {
      getLogger(observed).finer(() => LogObject(observed, message, data));
    }
  }

  void finest(dynamic observed, LogMessage message,
      {Map<String, dynamic> data}) {
    if (Logger.root.isLoggable(Level.FINEST)) {
      getLogger(observed).finest(() => LogObject(observed, message, data));
    }
  }

  static dynamic observe(dynamic object, List<String> filterObservables) {
    if (object == null) {
      return null;
    }
    dynamic observed = (object as LogObject).observed;

    if (filterObservables.length == 0 ||
        filterObservables.fold(
            false,
            (report, String objectType) =>
                (report || observed.runtimeType.toString() == objectType))) {
      return observed;
    }
    return null;
  }

  static void logLine(LogLine line) {
    print(
        '${line.record.level.name}: ${line.record.time}: ${line.record.message}\n');
  }

  static void configure(
      {dynamic level = Level.INFO,
      bool stackTrace = false,
      List<String> filterObservables = const [],
      LogFormatter logFunction = logLine}) {
    if (level is String) {
      switch (level) {
        case "ALL":
          level = Level.ALL;
          break;
        case "FINEST":
          level = Level.FINEST;
          break;
        case "FINER":
          level = Level.FINER;
          break;
        case "FINE":
          level = Level.FINE;
          break;
        case "CONFIG":
          level = Level.CONFIG;
          break;
        case "WARNING":
          level = Level.WARNING;
          break;
        case "SEVERE":
          level = Level.SEVERE;
          break;
        case "SHOUT":
          level = Level.SHOUT;
          break;
        case "INFO":
        default:
          level = Level.INFO;
          break;
      }
      Logger.root.level = level;
    } else if (level is Level) {
      Logger.root.level = level;
    } else {
      Logger.root.level = Level.INFO;
    }
    if (stackTrace) {
      recordStackTraceAtLevel = Level.ALL;
    }

    Logger.root.onRecord.listen((record) => logFunction(LogLine(
        record: record, observed: observe(record.object, filterObservables))));
  }
}
