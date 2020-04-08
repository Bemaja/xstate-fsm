import 'package:logging/logging.dart';

typedef LogMessage = String Function();

class LogObject {
  final dynamic observed;
  final LogMessage message;
  final Map<String, dynamic> data;

  const LogObject(this.observed, this.message, this.data);

  @override
  String toString() => message();
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
}
