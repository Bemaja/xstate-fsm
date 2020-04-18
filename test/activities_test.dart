import 'package:test/test.dart';
import 'package:xstate_fsm/xstate_fsm.dart';

ActionStartActivity start(String activity) =>
    ActionStandardStartActivity(StandardActivity(activity, (c, a) => () => {}));

ActionStopActivity stop(String activity) =>
    ActionStandardStopActivity(StandardActivity(activity, (c, a) => () => {}));

void main() {
  var machine = Setup().machine({
    "key": "light",
    "initial": "green",
    "states": {
      "green": {
        "activities": ["fadeInGreen"],
        "on": {"TIMER": "yellow"}
      },
      "yellow": {
        "on": {"TIMER": "red"}
      },
      "red": {
        "initial": "walk",
        "activities": ["activateCrosswalkLight"],
        "on": {"TIMER": "green"},
        "states": {
          "walk": {
            "on": {"PED_WAIT": "wait"}
          },
          "wait": {
            "activities": ["blinkCrosswalkLight"],
            "on": {"PED_STOP": "stop"}
          },
          "stop": {}
        }
      }
    }
  }, activities: [
    StandardActivity('fadeInGreen', (c, a) => () => {}),
    StandardActivity('activateCrosswalkLight', (c, a) => () => {}),
    StandardActivity('blinkCrosswalkLight', (c, a) => () => {})
  ]);

  group("Activities", () {
    test("initial state has initial activities", () {
      expect(machine.initialState.activities["fadeInGreen"], isNotNull);
    });
    test("identifies running activities", () {
      var nextState = machine.transitionUntyped('yellow', 'TIMER');
      expect(nextState.activities["activateCrosswalkLight"], isTrue);
    });
    test("identifies activities to be started", () {
      var nextState = machine.transitionUntyped('yellow', 'TIMER');
      expect(nextState.actions, equals([start('activateCrosswalkLight')]));
    });
    test("identifies started activities for child states", () {
      var redWalkState = machine.transitionUntyped('yellow', 'TIMER');
      var nextState = machine.transitionUntyped(redWalkState, 'PED_WAIT');

      expect(nextState.activities["activateCrosswalkLight"], isTrue);
      expect(nextState.activities["blinkCrosswalkLight"], isTrue);
    });
    test("identifies activities to be started for child states", () {
      var redWalkState = machine.transitionUntyped('yellow', 'TIMER');
      var nextState = machine.transitionUntyped(redWalkState, 'PED_WAIT');

      expect(nextState.actions, equals([start('blinkCrosswalkLight')]));
    });
    test("identifies stopped activities for child states", () {
      var redWalkState = machine.transitionUntyped('yellow', 'TIMER');
      var redWaitState = machine.transitionUntyped(redWalkState, 'PED_WAIT');
      var nextState = machine.transitionUntyped(redWaitState, 'PED_STOP');

      expect(nextState.activities["activateCrosswalkLight"], isTrue);
      expect(nextState.activities["blinkCrosswalkLight"], isFalse);
    });
    test("identifies activities to be stopped for child states", () {
      var redWalkState = machine.transitionUntyped('yellow', 'TIMER');
      var redWaitState = machine.transitionUntyped(redWalkState, 'PED_WAIT');
      var nextState = machine.transitionUntyped(redWaitState, 'PED_STOP');

      expect(nextState.actions, equals([stop('blinkCrosswalkLight')]));
    });
    test("identifies stopped activities for child states", () {
      var redWalkState = machine.transitionUntyped('yellow', 'TIMER');
      var redWaitState = machine.transitionUntyped(redWalkState, 'PED_WAIT');
      var redStopState = machine.transitionUntyped(redWaitState, 'PED_STOP');
      var nextState = machine.transitionUntyped(redStopState, 'TIMER');

      expect(nextState.activities["activateCrosswalkLight"], isFalse);
      expect(nextState.activities["blinkCrosswalkLight"], isFalse);
      expect(nextState.activities["fadeInGreen"], isTrue);
    });
    test("identifies activities to be stopped for child states", () {
      var redWalkState = machine.transitionUntyped('yellow', 'TIMER');
      var redWaitState = machine.transitionUntyped(redWalkState, 'PED_WAIT');
      var redStopState = machine.transitionUntyped(redWaitState, 'PED_STOP');
      var nextState = machine.transitionUntyped(redStopState, 'TIMER');

      expect(nextState.actions,
          equals([stop('activateCrosswalkLight'), start('fadeInGreen')]));
    });
  });
}
