import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:xstate_fsm/xstate_fsm.dart';

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
  });

  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}\n');
  });

  group("Activities", () {
    test("initial state has initial activities", () {
      expect(machine.initialState.activities["fadeInGreen"], isNotNull);
    });
    test("initial state has initial activities", () {
      expect(machine.initialState.activities["fadeInGreen"], isNotNull);
    });
    test("identifies start activities", () {
      var nextState =
          machine.transition(State(machine.select('yellow')), Event('TIMER'));
      expect(nextState.activities["activateCrosswalkLight"], isNotNull);
//        expect(nextState.actions).toEqual([start('activateCrosswalkLight')]);
    });
  });
}
