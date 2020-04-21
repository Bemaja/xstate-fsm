import 'package:test/test.dart';
import 'package:xstate_fsm/xstate_fsm.dart';
import 'package:equatable/equatable.dart';

import './util.dart';

class LightContext extends Equatable {
  final num count;
  final String foo;
  final bool go;

  const LightContext({this.count = 0, this.foo = "", this.go = false});

  @override
  List<Object> get props => [count, foo, go];

  @override
  bool get stringify => true;
}

class LightContextFactory extends ContextFactory<LightContext> {
  @override
  LightContext fromMap(Map<String, dynamic> map) {
    return LightContext(count: map['count'], foo: map['foo'], go: map['go']);
  }

  @override
  LightContext copy(LightContext original) =>
      LightContext(count: original.count, foo: original.foo, go: original.go);
}

class LightEvent {
  final num value;

  const LightEvent(this.value);
}

/*
   LightEvent =
    | { type: 'TIMER' }
    | { type: 'INC' }
    | { type: 'EMERGENCY'; value: number };
*/

/*
  interface LightContext {
    count: number;
    foo: string | undefined;
    go: boolean;
  }

  type LightState =
    | {
        value: 'green';
        context: LightContext & { go: true };
      }
    | {
        value: 'yellow';
        context: LightContext & { go: false };
      };
*/

void main() {
  Map<String, dynamic> lightConfig = {
    "strict": true,
    "id": "light",
    "initial": "green",
    "context": {"count": 0, "foo": 'bar', "go": true},
    "states": {
      "green": {
        "onEntry": 'enterGreen',
        "onExit": [
          "exitGreen",
          "g-a 1",
          "g-a 2",
          "g-a 3",
          "g-a 4",
        ],
        "on": {
          "TIMER": {
            "target": 'yellow',
            "actions": ['g-y 1', 'g-y 2']
          }
        }
      },
      "yellow": {
        "onEntry": "y-e 1",
        "on": {
          "INC": {
            "actions": ["y-o 1"]
          },
          "EMERGENCY": {"target": 'red', "cond": 'y-g 1'}
        }
      },
      "red": {}
    }
  };

  var lightFSM = Setup<LightContext, LightEvent>()
      .machine(lightConfig, contextFactory: LightContextFactory(), actions: {
    "enterGreen": ActionStandard("enterGreen"),
    "exitGreen": ActionStandard("exitGreen"),
    "g-y 1": ActionStandard("g-y 1"),
    "g-y 2": ActionStandard("g-y 2")
  }, assignments: {
    "g-a 1": ActionStandardAssign<LightContext, LightEvent>(
        (LightContext c, Event<LightEvent> e) =>
            LightContext(count: c.count + 1, foo: c.foo, go: c.go)),
    "g-a 2": ActionStandardAssign<LightContext, LightEvent>(
        (LightContext c, Event<LightEvent> e) =>
            LightContext(count: c.count + 1, foo: c.foo, go: c.go)),
    "g-a 3": ActionStandardAssign<LightContext, LightEvent>(
        (LightContext c, Event<LightEvent> e) =>
            LightContext(count: c.count, foo: 'static', go: c.go)),
    "g-a 4": ActionStandardAssign<LightContext, LightEvent>(
        (LightContext c, Event<LightEvent> e) =>
            LightContext(count: c.count, foo: c.foo + '++', go: c.go)),
    "y-e 1": ActionStandardAssign<LightContext, LightEvent>(
        (LightContext c, Event<LightEvent> e) =>
            LightContext(count: c.count, foo: c.foo, go: false)),
    "y-o 1": ActionStandardAssign<LightContext, LightEvent>(
        (LightContext c, Event<LightEvent> e) =>
            LightContext(count: c.count + 1, foo: c.foo, go: c.go))
  }, guards: {
    "y-g 1": GuardConditional<LightContext, LightEvent>(
        (LightContext c, Event<LightEvent> e) =>
            c.count + e.externalEvent.value == 2,
        type: "y-g 1")
  });

  group('Machine', () {
    test('should return back the config object', () {
      expect(lightFSM.config, equals(lightConfig));
    });

    test('should have the correct initial state', () {
      expect(lightFSM.initialState.value.toStateValue(), equals('green'));
    });

    test('should have the correct initial actions', () {
      expect(lightFSM.initialState.actions,
          equals([ActionStandard('enterGreen')]));
    });

    test('should transition correctly', () {
      var nextState = lightFSM.transition(
          StandardState<LightContext, LightEvent>(lightFSM.select('green'),
              context: LightContext(count: 0, foo: 'bar', go: true)),
          Event('TIMER'));
      expect(nextState.value.toStateValue(), equals('yellow'));
      expect(
          nextState.actions,
          equals(
              [lightFSM['exitGreen'], lightFSM['g-y 1'], lightFSM['g-y 2']]));
      expect(nextState.context,
          equals(LightContext(count: 2, foo: 'static++', go: false)));
    });

    test('should stay on the same state for undefined transitions', () {
      var nextState = lightFSM.transition(
          StandardState<LightContext, LightEvent>(lightFSM.select('green'),
              context: LightContext(count: 0, foo: 'bar', go: true)),
          Event('FAKE'));
      expect(nextState.value.toStateValue(), equals('green'));
      expect(nextState.actions, equals([]));
    });

    test('should throw an error for undefined states', () {
      expect(
          () => lightFSM.transition(
              StandardState(lightFSM.select('unknown')), Event('TIMER')),
          throwsA(isA<Exception>()));
    });

    test('should work with guards', () {
      var yellowState = lightFSM.transition(
          StandardState(lightFSM.select('yellow'), context: LightContext()),
          Event('EMERGENCY',
              data: ExternalEventData<LightEvent>(LightEvent(0))));
      expect(yellowState.value.toStateValue(), 'yellow');

      var redState = lightFSM.transition(
          StandardState(lightFSM.select('yellow'), context: LightContext()),
          Event('EMERGENCY',
              data: ExternalEventData<LightEvent>(LightEvent(2))));
      expect(redState.value.toStateValue(), equals('red'));
      expect(redState.context.count, equals(0));
      var yellowOneState = lightFSM.transition(
          StandardState(lightFSM.select('yellow'), context: LightContext()),
          Event('INC', data: ExternalEventData<LightEvent>(LightEvent(0))));
      stopLog();
      var redOneState = lightFSM.transition(
          yellowOneState,
          Event('EMERGENCY',
              data: ExternalEventData<LightEvent>(LightEvent(1))));

      expect(redOneState.value.toStateValue(), equals('red'));
      expect(redOneState.context.count, equals(1));
    });

    test('should be changed if state changes', () {
      expect(
          lightFSM
              .transition(
                  StandardState(lightFSM.select('green'),
                      context: LightContext()),
                  Event('TIMER'))
              .changed,
          equals(true));
    });

    test('should be changed if any actions occur', () {
      expect(
          lightFSM
              .transition(
                  StandardState(lightFSM.select('yellow'),
                      context: LightContext()),
                  Event('INC'))
              .changed,
          equals(true));
    });

    test('should not be changed on unknown transitions', () {
      expect(
          lightFSM
              .transition(
                  StandardState(lightFSM.select('yellow'),
                      context: LightContext()),
                  Event('UNKNOWN'))
              .changed,
          equals(false));
    });

    test('should match initialState', () {
      expect(lightFSM.initialState.matches('green'), equals(true));
      expect(lightFSM.initialState.context.go, equals(true));
    });

    test('should match transition states', () {
      var nextState =
          lightFSM.transition(lightFSM.initialState, Event('TIMER'));

      expect(nextState.matches('yellow'), equals(true));

      expect(nextState.context.go, equals(false));
    });
  });

  group('Interpreter', () {
    var toggleMachine = Setup().machine({
      "initial": "active",
      "states": {
        "active": {
          "on": {
            "TOGGLE": {"target": "inactive"}
          }
        },
        "inactive": {},
      }
    });

    test('listeners should immediately get the initial state', () {
      var toggleService = Interpreter(toggleMachine).start();

      toggleService.subscribe((state, {event}) {
        expect(state.matches('active'), equals(true));
      });
    });

    test('listeners should subscribe to state changes', () {
      var toggleService = Interpreter(toggleMachine).start();

      var count = 0;

      toggleService.subscribe((state, {event}) {
        count += 1;
        if (count == 2) {
          expect(state.matches('inactive'), equals(true));
        }
      });
      toggleService.send(Event('TOGGLE'));
    });
  });

  test('should execute actions', () {
    var executed = false;
    var count = 0;

    Map<String, dynamic> actionConfig = {
      "initial": 'active',
      "states": {
        "active": {
          "on": {
            "TOGGLE": {
              "target": 'inactive',
              "actions": ["action"]
            }
          }
        },
        "inactive": {}
      }
    };

    var actionMachine = Setup().machine(actionConfig, executions: {
      "action": ActionStandardExecute("action", (context, event) {
        executed = true;
      })
    });

    var actionService = Interpreter(actionMachine).start();

    actionService.subscribe((state, {event}) {
      count += 1;
      if (count == 2) {
        expect(executed, equals(true));
      }
    });

    actionService.send(Event('TOGGLE'));
  });

  test('should execute initial entry action', () {
    var executed = false;

    Map<String, dynamic> actionConfig = {
      "initial": 'foo',
      "states": {
        "foo": {"onEntry": "action"},
      }
    };

    var actionMachine = Setup().machine(actionConfig, executions: {
      "action": ActionStandardExecute("action", (context, event) {
        executed = true;
      })
    });

    Interpreter(actionMachine).start();

    expect(executed, equals(true));
  });
}
