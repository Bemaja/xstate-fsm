import 'package:test/test.dart';
import 'package:xstate_fsm/xstate_fsm.dart';
import 'dart:async';

class CountContext {
  final num count;
  const CountContext({this.count = 0});
}

void main() {
  group("Services", () {
    test('should be started', () async {
      var count;
      Completer _completer = new Completer();
      Interpreter(Setup<CountContext, dynamic>().machine({
        "id": 'parent',
        "initial": 'start',
        "states": {
          "start": {
            "invoke": {
              "src": {
                "id": 'child',
                "initial": 'init',
                "states": {
                  "init": {
                    "onEntry": [
                      ActionStandardSendParent<CountContext, dynamic>(
                          Event('INC')),
                      ActionStandardSendParent<CountContext, dynamic>(
                          Event('INC'))
                    ]
                  }
                }
              },
              "id": 'someService',
              "autoForward": true
            },
            "on": {
              "INC": {"actions": "counter"},
              '': {
                "target": 'stop',
                "cond": GuardConditional<CountContext, dynamic>(
                    (CountContext c, dynamic event) => c.count == 2)
              }
            }
          },
          "stop": {"type": 'final'}
        }
      }, assignments: {
        "counter": ActionStandardAssign<CountContext, dynamic>(
            (CountContext context, event) =>
                CountContext(count: context.count + 1))
      }, initialContext: CountContext()))
          .onTransition((state, {event}) {
        print('HERE1');
        count = state.context.count;
      }).onDone((event) {
        // 1. The 'parent' machine will enter 'start' state
        // 2. The 'child' service will be run with ID 'someService'
        // 3. The 'child' machine will enter 'init' state
        // 4. The 'entry' action will be executed, which sends 'INC' to 'parent' machine twice
        // 5. The context will be updated to increment count to 2
        print('HERE2');
        _completer.complete(count);
        //done();
      }).start();
      var result = await _completer.future;

      expect(result, equals(2));
    });
  });
}
