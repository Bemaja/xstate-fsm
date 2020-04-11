import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:xstate_fsm/xstate_fsm.dart';

/**
 * Usage:
 *
 *      debugLog(filterObservables: ['StateTreeNode<LightContext, LightEvent>']);
 *      stopLog();
 */

void debugLog({List<String> filterObservables = const []}) {
  Log.configure(
      level: Level.ALL,
      stackTrace: true,
      filterObservables: filterObservables,
      logFunction: (LogLine line) {
        String framePart;
        if (line.record.stackTrace != null) {
          Trace trace = Trace.from(line.record.stackTrace);
          Frame frame = trace.frames[3];
          framePart = "${frame.uri}: ${frame.line}: ${frame.member}: ";
        }
        if (line.observed != null) {
          print(
              '${framePart ?? ''}${line.observed.toString() + ' '}${line.record.message}\n');
        }
//    print(
//        '${record.level.name}: ${record.time}: ${framePart ?? ''}${record.message}\n');
      });
}

void stopLog() {
  Log.configure(level: Level.OFF, stackTrace: false);
}
