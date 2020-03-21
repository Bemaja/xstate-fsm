import 'package:test/test.dart';
import 'package:xstate_fsm/xstate_fsm.dart';
import 'package:equatable/equatable.dart';

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

class LightState {}

/*
  LightState =
    | {
        value: 'green';
        context: LightContext & { go: true };
      }
    | {
        value: 'yellow';
        context: LightContext & { go: false };
      };

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
  Options<LightContext, LightEvent> options =
      Options(contextFactory: LightContextFactory());
  options.actionMap.registerAction("enterGreen");
  options.actionMap.registerAction("exitGreen");
  options.actionMap.registerAction("g-y 1");
  options.actionMap.registerAction("g-y 2");
  options.actionMap.registerAssignment(
      "g-a 1",
      (LightContext c, Event<LightEvent> e) =>
          LightContext(count: c.count + 1, foo: c.foo, go: c.go));
  options.actionMap.registerAssignment(
      "g-a 2",
      (LightContext c, Event<LightEvent> e) =>
          LightContext(count: c.count + 1, foo: c.foo, go: c.go));
  options.actionMap.registerAssignment(
      "g-a 3",
      (LightContext c, Event<LightEvent> e) =>
          LightContext(count: c.count, foo: 'static', go: c.go));
  options.actionMap.registerAssignment(
      "g-a 4",
      (LightContext c, Event<LightEvent> e) =>
          LightContext(count: c.count, foo: c.foo + '++', go: c.go));
  options.actionMap.registerAssignment(
      "y-e 1",
      (LightContext c, Event<LightEvent> e) =>
          LightContext(count: c.count, foo: c.foo, go: false));

  options.actionMap.registerAssignment(
      "y-o 1",
      (LightContext c, Event<LightEvent> e) =>
          LightContext(count: c.count + 1, foo: c.foo, go: c.go));

  options.guardMap.registerGuard("y-g 1",
      (LightContext c, Event<LightEvent> e) => c.count + e.event.value == 2);

  Map<String, dynamic> lightConfig = {
    "id": "light",
    "initial": "green",
    "context": {"count": 0, "foo": 'bar', "go": true},
    "states": {
      "green": {
        "entry": 'enterGreen',
        "exit": [
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
        "entry": "y-e 1",
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
  Config<LightContext, LightEvent> config =
      Config.fromConfig(lightConfig, options: options);

  var lightFSM = Machine(config, options: options);

  group('Machine', () {
    test('should return back the config object', () {
      expect(lightFSM.config, isA<Config>());
    });

    test('should have the correct initial state', () {
      expect(lightFSM.initialState.value, equals('green'));
    });

    test('should have the correct initial actions', () {
      expect(lightFSM.initialState.actions, equals([lightFSM['enterGreen']]));
    });

    test('should transition correctly', () {
      var nextState = lightFSM.transition(
          State<LightContext, LightEvent>('green',
              context: LightContext(count: 0, foo: 'bar', go: true)),
          Event('TIMER'));
      expect(nextState.value, equals('yellow'));
      expect(
          nextState.actions,
          equals(
              [lightFSM['exitGreen'], lightFSM['g-y 1'], lightFSM['g-y 2']]));
      expect(nextState.context,
          equals(LightContext(count: 2, foo: 'static++', go: false)));
    });

    test('should stay on the same state for undefined transitions', () {
      var nextState = lightFSM.transition(
          State<LightContext, LightEvent>('green',
              context: LightContext(count: 0, foo: 'bar', go: true)),
          Event('FAKE'));
      expect(nextState.value, equals('green'));
      expect(nextState.actions, equals([]));
    });

    test('should throw an error for undefined states', () {
      expect(() => lightFSM.transition(State('unknown'), Event('TIMER')),
          throwsA(isA<AssertionError>()));
    });

    test('should work with guards', () {
      var yellowState = lightFSM.transition(
          State('yellow', context: LightContext()),
          Event('EMERGENCY', event: LightEvent(0)));
      expect(yellowState.value, 'yellow');

      var redState = lightFSM.transition(
          State('yellow', context: LightContext()),
          Event('EMERGENCY', event: LightEvent(2)));
      expect(redState.value, equals('red'));
      expect(redState.context.count, equals(0));

      var yellowOneState = lightFSM.transition(
          State('yellow', context: LightContext()),
          Event('INC', event: LightEvent(0)));
      var redOneState = lightFSM.transition(
          yellowOneState, Event('EMERGENCY', event: LightEvent(1)));

      expect(redOneState.value, equals('red'));
      expect(redOneState.context.count, equals(1));
    });

    test('should be changed if state changes', () {
      expect(
          lightFSM
              .transition(
                  State('green', context: LightContext()), Event('TIMER'))
              .changed,
          equals(true));
    });

    test('should be changed if any actions occur', () {
      expect(
          lightFSM
              .transition(
                  State('yellow', context: LightContext()), Event('INC'))
              .changed,
          equals(true));
    });

    test('should not be changed on unknown transitions', () {
      expect(
          lightFSM
              .transition(
                  State('yellow', context: LightContext()), Event('UNKNOWN'))
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
    Map<String, dynamic> toggleConfig = {
      "initial": "active",
      "states": {
        "active": {
          "on": {
            "TOGGLE": {"target": "inactive"}
          }
        },
        "inactive": {},
      }
    };

    Config<dynamic, dynamic> config = Config.fromConfig(toggleConfig);

    var toggleMachine = Machine(config);

    test('listeners should immediately get the initial state', () {
      var toggleService = Interpreter(toggleMachine).start();

      toggleService.subscribe((state) {
        expect(state.matches('active'), equals(true));
      });
    });

    test('listeners should subscribe to state changes', () {
      var toggleService = Interpreter(toggleMachine).start();

      var count = 0;

      toggleService.subscribe((state) {
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

    Options<dynamic, dynamic> options = Options();
    options.actionMap.registerExecution("action", (context, event) {
      executed = true;
    });
    Config<dynamic, dynamic> config =
        Config.fromConfig(actionConfig, options: options);

    var actionMachine = Machine(config, options: options);

    var actionService = Interpreter(actionMachine).start();

    actionService.subscribe((state) {
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
        "foo": {"entry": "action"},
      }
    };

    Options<dynamic, dynamic> options = Options();
    options.actionMap.registerExecution("action", (context, event) {
      executed = true;
    });
    Config<dynamic, dynamic> config =
        Config.fromConfig(actionConfig, options: options);

    var actionMachine = Machine(config, options: options);

    Interpreter(actionMachine).start();

    expect(executed, equals(true));
  });
}
