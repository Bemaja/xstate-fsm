import 'dart:async';
import 'log.dart';
import 'interfaces.dart';

// FIX import
import 'services.dart';

typedef StateListener<C, E> = Function(State<C, E> state, {Event<E> event});

typedef EventListener<E> = Function(Event<E> event);

abstract class LaymanActor<E> {
  void send(Event<E> event);
}

class Interpreter<C, E> extends LaymanActor<E> {
  final StateNode<C, E> machine;
  List<StateListener<C, E>> _listeners = [];
  List<EventListener<E>> _doneListeners = [];
  State<C, E> _currentState;
  Interpreter parent;

  Map<String, LaymanActor> children = {};

  StreamController<Event<E>> eventSink;
  StreamSubscription<Event<E>> eventSubscription;

  Log log = Log();

  Interpreter(StateNode<C, E> this.machine, {Interpreter this.parent})
      : _currentState = machine.initialState;

  bool get isRunning => eventSink != null && eventSink.hasListener;

  void _executeStateActions(State<C, E> state, Event<E> event) {
    for (Action action in state.actions) {
      if (action is ActionExecute<C, E>) {
        action.execute(state.context, event);
      } else if (action is ActionSend<E>) {
        sendTo(action.event, action.to);
      } else if (action is ActionStartService<C, E>) {
        Service<C, E> service = action.service;
        if (service is ServiceMachine<C, E>) {
          Interpreter child = Interpreter(service.machine, parent: this);
          /* origin ? */
          child.onDone((doneEvent) => send(doneEvent)).start();
          children[service.machine.id] = child;
        }
      }
    }
  }

  void onEvent(Event<E> event) {
    _currentState = machine.transition(_currentState, event);
    _executeStateActions(_currentState, event);
    _listeners.forEach((listener) => listener(_currentState, event: event));
    if (_currentState.value.type.isFinal) {
      _doneListeners.forEach((listener) => listener(Event<E>.internal(
          "done.invoke.${machine.id}",
          InternalEventData(DoneEvent(/* data? */)))));
    }
  }

  @override
  void send(Event<E> event) {
    if (!isRunning) {
      throw Exception("Interpreter is not running, not taking events");
    }
    eventSink.add(event);
  }

  void sendTo(Event<E> event, String to) {
    if (to == '#_parent') {
      if (parent == null) {
        log.severe(this,
            () => "Send ${event} from ${machine.id} to nonexistant parent");
      } else {
        log.fine(
            this,
            () =>
                "Send ${event} from \"${machine.id}\" to \"${parent.machine.id}\"");
        parent.send(event);
      }
    } else if (children[to] != null) {
      children[to].send(event);
    }
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
    eventSink = StreamController<Event<E>>();
    eventSubscription = eventSink.stream.listen(onEvent);
    _executeStateActions(_currentState, null);
    return this;
  }

  Interpreter<C, E> stop() {
    if (eventSubscription == null) {
      return this;
    }
    eventSubscription.cancel();
    eventSink.close();
    eventSink = null;
    return this;
  }
}
