import 'interfaces.dart';

enum InterpreterStatus { NotStarted, Running, Stopped }

typedef StateListener<C, E> = Function(State<C, E> state, {Event<E> event});

typedef EventListener<E> = Function(Event<E> event);

class Interpreter<C, E> {
  static const INIT_EVENT = Event('xstate.init');

  final StateNode<C, E> machine;
  InterpreterStatus _status;
  List<StateListener<C, E>> _listeners = [];
  List<EventListener<E>> _doneListeners = [];
  State<C, E> _currentState;

  Interpreter(StateNode<C, E> this.machine)
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
    _listeners.forEach((listener) => listener(_currentState, event: event));
  }

  Map<String, Function()> subscribe(StateListener<C, E> listener) {
    _listeners.add(listener);
    listener(_currentState);

    return {"unsubscribe": () => _listeners.remove(listener)};
  }

  Interpreter<C, E> onTransition(StateListener<C, E> listener) {
    _listeners.add(listener);
    listener(_currentState);

    return this;
  }

  Interpreter<C, E> onDone(EventListener<E> listener) {
    _doneListeners.add(listener);

    return this;
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
