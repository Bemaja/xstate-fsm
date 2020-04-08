import 'package:equatable/equatable.dart';
import 'activities.dart';
import 'event.dart';

class Action<C, E> extends Equatable {
  final String type;

  const Action(String this.type);

  @override
  List<Object> get props => [type];

  @override
  String toString() {
    return "${Action} of \"${type}\"";
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

class ActionStart<C, E> extends Action<C, E> {
  final Activity<C, E> activity;

  const ActionStart(this.activity) : super('xstate.start');

  @override
  List<Object> get props => [type, activity];

  @override
  String toString() {
    return "${ActionStart}(${activity})";
  }
}

class ActionStop<C, E> extends Action<C, E> {
  final Activity<C, E> activity;

  const ActionStop(this.activity) : super('xstate.stop');

  @override
  List<Object> get props => [type, activity];

  @override
  String toString() {
    return "${ActionStop}(${activity})";
  }
}
