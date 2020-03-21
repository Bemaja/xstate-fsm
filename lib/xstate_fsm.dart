import 'package:equatable/equatable.dart';

//***********************************************
// ACTIONS
//***********************************************

class Action<C, E> extends Equatable {
  final String type;

  const Action(String this.type);

  @override
  List<Object> get props => [type];

  @override
  String toString() {
    return "ActionObject of \"${type}\"";
  }
}

typedef ActionExecution<C, E> = Function(C context, Event<E> event);

class ActionExecute<C, E> extends Action<C, E> {
  final ActionExecution<C, E> exec;

  const ActionExecute(type, ActionExecution<C, E> this.exec) : super(type);

  @override
  List<Object> get props => [type, exec];

  execute(C context, Event<E> event) => exec(context, event);
}

typedef ActionAssignment<C, E> = C Function(C context, Event<E> event);

class ActionAssign<C, E> extends Action<C, E> {
  final ActionAssignment<C, E> assignment;

  const ActionAssign(this.assignment) : super('xstate.assign');

  @override
  List<Object> get props => [type, assignment];

  C assign(C context, Event<E> event) => assignment(context, event);
}

enum ActionType { Action, Execution, Assignment }

//***********************************************
// GUARDS
//***********************************************

typedef GuardCondition<C, E> = bool Function(C context, Event<E> event);

abstract class Guard<C, E> {
  final String type;

  const Guard(String this.type);

  matches(C context, Event<E> event);
}

class GuardConditional<C, E> extends Guard<C, E> {
  final GuardCondition<C, E> condition;

  const GuardConditional(String type, GuardCondition<C, E> this.condition)
      : super(type);

  @override
  matches(C context, Event<E> event) => condition(context, event);
}

class GuardMatches<C, E> extends Guard<C, E> {
  const GuardMatches() : super('xstate.matches');

  @override
  matches(C context, Event<E> event) => true;
}

class GuardMap<C, E> {}

//***********************************************
// STATE / EVENT / CONTEXT
//***********************************************

class State<C, E> {
  String value;
  List<Action<C, E>> actions = [];
  C context;
  bool changed;
  StateMatcher matches;

  State(this.value,
      {this.actions, this.context = null, this.changed = false, this.matches});
}

class Event<E> {
  final String type;
  final E event;

  const Event(this.type, {this.event});
}

abstract class ContextFactory<C> {
  C fromMap(Map<String, dynamic> map);

  C copy(C original);
}

//***********************************************
// MAIN
//***********************************************

class ConfigTransition<C, E> {
  String target;
  List<Action<C, E>> actions;
  Guard<C, E> condition;

  ConfigTransition();

  ConfigTransition.fromConfig(
      Map<String, dynamic> transition, Machine<C, E> machine)
      : this.target = transition['target'],
// Ensure ['actions'] is a list
        this.actions = machine != null
            ? (transition['actions'] ?? []).map<Action<C, E>>((action) {
                Action<C, E> actionObject = machine[action];
                return actionObject;
              }).toList()
            : [],
        this.condition = (transition['cond'] != null)
            ? machine.getGuard(transition['cond'])
            : GuardMatches<C, E>();

  bool doesNotMatch(C context, Event<E> event) {
    return condition != null && !condition.matches(context, event);
  }

  State<C, E> transition(State<C, E> state, Event<E> event,
      StateResolver<C, E> resolver, List<Action<C, E>> exits) {
    ConfigState<C, E> targetState = resolver(target ?? state.value);

    List<Action<C, E>> allActions =
        (exits ?? []) + (actions ?? []) + (targetState.entries ?? []);

    return State(target ?? state.value,
        context: allActions.fold<C>(state.context,
            (C oldContext, Action<C, E> action) {
          if (action is ActionAssign<C, E>) {
            return action.assign(oldContext, event);
          } else {
            return oldContext;
          }
        }),
        actions:
            allActions.where((action) => !(action is ActionAssign)).toList(),
        changed: target != state.value ||
            !allActions.isEmpty ||
            allActions.fold<bool>(
                false,
                (bool changed, Action<C, E> action) =>
                    changed || (action is ActionAssign)),
        matches: (String stateValue) => stateValue == target);
  }
}

class ConfigNoTransition<C, E> extends ConfigTransition<C, E> {
  State<C, E> transition(State<C, E> state, Event<E> event,
      StateResolver<C, E> resolver, List<Action<C, E>> exits) {
    return State(state.value,
        context: state.context,
        actions: [],
        changed: false,
        matches: (String stateValue) => stateValue == state.value);
  }
}

class ConfigTransitions<C, E> {
  Map<String, List<ConfigTransition<C, E>>> transitions;

  ConfigTransitions.fromConfig(
      Map<String, dynamic> transitions, Machine<C, E> machine)
      : this.transitions = transitions.map((String key, dynamic transition) =>
            MapEntry(
                key,
                transition is List
                    ? transition
                        .map((t) => ConfigTransition.fromConfig(t, machine))
                    : [ConfigTransition.fromConfig(transition, machine)]));

  List<ConfigTransition<C, E>> getTransitionFor(Event<E> event) {
    if (!transitions.containsKey(event.type)) {
      return [ConfigNoTransition()];
    }
    return transitions[event.type];
  }
}

class ConfigState<C, E> {
  List<Action<C, E>> entries;
  List<Action<C, E>> exits;
  ConfigTransitions<C, E> transitions;

  ConfigState();

  ConfigState.fromConfig(dynamic state, Machine<C, E> machine)
      : this.entries =
            machine != null ? machine.getActions(state['entry']) : [],
        this.exits = machine != null ? machine.getActions(state['exit']) : [],
        this.transitions =
            ConfigTransitions.fromConfig(state['on'] ?? {}, machine);

  State<C, E> transition(
      State<C, E> state, Event<E> event, StateResolver<C, E> resolver) {
    var matchingTransitions = transitions.getTransitionFor(event).skipWhile(
        (transition) => transition.doesNotMatch(state.context, event));
    return (matchingTransitions.isEmpty
            ? ConfigNoTransition<C, E>()
            : matchingTransitions.first)
        .transition(state, event, resolver, exits);
  }
}

typedef StateResolver<C, E> = ConfigState<C, E> Function(String target);

class ConfigStates<C, E> {
  Map<String, ConfigState<C, E>> states;
  String id;

  ConfigStates(this.states);

  ConfigStates.fromConfig(Map<String, dynamic> states,
      {Machine<C, E> machine, String this.id})
      : this.states = states.map((String key, dynamic state) =>
            MapEntry(key, ConfigState.fromConfig(state, machine)));

  ConfigState<C, E> resolveTarget(String target) {
    if (!states.containsKey(target)) {
      assert(states.containsKey(target),
          "State ${target} not found on machine${id}.");
      return ConfigState();
    } else {
      return states[target];
    }
  }

  State<C, E> transition(State<C, E> state, Event<E> event) {
    if (!states.containsKey(state.value)) {
      assert(states.containsKey(state.value),
          "State ${state.value} not found on machine${id}.");
      return ConfigNoTransition()
          .transition(state, event, this.resolveTarget, []);
    } else {
      return states[state.value].transition(state, event, this.resolveTarget);
    }
  }
}

class Config<C, E> {
  String id;
  String initial;
  Map<String, dynamic> context;
  ConfigStates<C, E> states;

  Config.fromConfig(Map<String, dynamic> config, {Machine<C, E> machine})
      : this.initial = config['initial'] ?? '',
        this.id = config['id'] ?? '',
        this.context = config['context'] ?? {},
        this.states = ConfigStates.fromConfig(config['states'],
            machine: machine, id: config['id'] ?? '');

  State<C, E> transition(State<C, E> state, Event<E> event) {
    return states.transition(state, event);
  }
}

typedef StateMatcher = bool Function(String);

StateMatcher createStateMatcher(String value) {
  return (String stateValue) => stateValue == value;
}

class Machine<C, E> {
  final Config<C, E> config;

  final Map<String, Action<C, E>> actions;
  final Map<String, ActionExecute<C, E>> executions;
  final Map<String, ActionAssign<C, E>> assignments;

  final Map<String, Guard<C, E>> guards;

  final ContextFactory<C> contextFactory;

  const Machine(
      {this.config,
      this.contextFactory,
      this.actions = const {},
      this.executions = const {},
      this.assignments = const {},
      this.guards = const {}});

  Machine<C, E> configure(Map<String, dynamic> config) => Machine<C, E>(
      config: Config<C, E>.fromConfig(config, machine: this),
      actions: actions,
      executions: executions,
      assignments: assignments,
      guards: guards,
      contextFactory: contextFactory);

  Machine<C, E> action(String action) => Machine<C, E>(
      config: config,
      actions: {...actions, action: Action<C, E>(action)},
      executions: executions,
      assignments: assignments,
      guards: guards,
      contextFactory: contextFactory);

  Machine<C, E> execution(String action, ActionExecution<C, E> exec) =>
      Machine<C, E>(
          config: config,
          actions: actions,
          executions: {
            ...executions,
            action: ActionExecute<C, E>(action, exec)
          },
          assignments: assignments,
          guards: guards,
          contextFactory: contextFactory);

  Machine<C, E> assignment(String action, ActionAssignment<C, E> assignment) =>
      Machine<C, E>(
          config: config,
          actions: actions,
          executions: executions,
          assignments: {...assignments, action: ActionAssign<C, E>(assignment)},
          guards: guards,
          contextFactory: contextFactory);

  Machine<C, E> guard(String name, GuardCondition<C, E> condition) =>
      Machine<C, E>(
          config: config,
          actions: actions,
          executions: executions,
          assignments: assignments,
          guards: {...guards, name: GuardConditional<C, E>(name, condition)},
          contextFactory: contextFactory);

  State<C, E> get initialState =>
      config.initial != null && config.states.states.containsKey(config.initial)
          ? State<C, E>(config.initial,
              actions: config.states.states[config.initial].entries,
              context: !config.context.isEmpty
                  ? contextFactory.fromMap(config.context)
                  : null,
              matches: (String stateValue) => stateValue == config.initial)
          : null;

  Action<C, E> operator [](String action) {
    if (actions.containsKey(action)) {
      return actions[action];
    } else if (executions.containsKey(action)) {
      return executions[action];
    } else if (assignments.containsKey(action)) {
      return assignments[action];
    }
    assert(false, "Action ${action} missing in action map");
    return Action("xstate.invalid");
  }

  List<Action<C, E>> getActions(dynamic action) {
    if (action is List) {
      return action
          .expand<Action<C, E>>((single) => getActions(single))
          .toList();
    } else if (action == null) {
      return [];
    } else if (action is String) {
      return [this[action]];
    }
    return [];
  }

  Guard<C, E> getGuard(String name) {
    assert(guards.containsKey(name),
        "Guard ${name} missing in guard map ${guards}");
    return guards[name];
  }

  State<C, E> transition(State<C, E> state, Event<E> event) {
    return config.transition(state, event);
  }
}

enum InterpreterStatus { NotStarted, Running, Stopped }

typedef StateListener<C, E> = Function(State<C, E> state);

class Interpreter<C, E> {
  static const INIT_EVENT = Event('xstate.init');

  final Machine<C, E> machine;
  InterpreterStatus _status;
  List<StateListener<C, E>> _listeners = [];
  State<C, E> _currentState;

  Interpreter(this.machine)
      : _status = InterpreterStatus.NotStarted,
        _currentState = machine.initialState;

  void _executeStateActions(State<C, E> state, Event<E> event) {
    for (Action<C, E> action in state.actions) {
      if (action is ActionExecute<C, E>) {
        action.execute(state.context, event);
      }
    }
  }

  void send(Event<E> event) {
    if (_status != InterpreterStatus.Running) {
      return;
    }
    _currentState = machine.transition(_currentState, event);
    _executeStateActions(_currentState, event);
    _listeners.forEach((listener) => listener(_currentState));
  }

  Map<String, Function()> subscribe(StateListener<C, E> listener) {
    _listeners.add(listener);
    listener(_currentState);

    return {"unsubscribe": () => _listeners.remove(listener)};
  }

  Interpreter<C, E> start() {
    _status = InterpreterStatus.Running;
    _executeStateActions(_currentState, INIT_EVENT);
    return this;
  }

  Interpreter<C, E> stop() {
    _status = InterpreterStatus.Stopped;
    _listeners.clear();
    return this;
  }

  InterpreterStatus get status => _status;
}
