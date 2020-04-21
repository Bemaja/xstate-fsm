import 'interfaces.dart';

class StandardActionFactory<C, E> extends ActionFactory<C, E> {
  @override
  ActionStandard createSimpleAction(String type) => ActionStandard(type);

  @override
  ActionAssign<C, E> createAssignmentAction(ActionAssignment<C, E> action) =>
      ActionStandardAssign<C, E>(action);

  @override
  ActionExecute<C, E> createExecutionAction(
          String type, ActionExecution<C, E> action) =>
      ActionStandardExecute<C, E>(type, action);

  @override
  Action createSendAction(Event<E> event, String to, {num delay, String id}) =>
      ActionStandardSend<E>(event, to, delay: delay, id: id);

  @override
  Action createDoneAction(String id, dynamic data) =>
      ActionStandardSendDone(Event.internal(
          "done.state.${id}", InternalEventData(DoneEvent(data: data))));

  @override
  Action createStartActivity(Activity<C, E> activity) =>
      ActionStandardStartActivity<C, E>(activity);

  @override
  Action createStopActivity(Activity<C, E> activity) =>
      ActionStandardStopActivity<C, E>(activity);

  @override
  Action createStartService(Service<C, E> service) =>
      ActionStandardStartService<C, E>(service);

  @override
  Action createStopService(Service<C, E> service) =>
      ActionStandardStopService<C, E>(service);
}

class ActionStandard extends Action {
  const ActionStandard(type) : super(type);
}

class ActionStandardExecute<C, E> extends ActionExecute<C, E> {
  const ActionStandardExecute(type, ActionExecution<C, E> exec)
      : super(type, exec);

  @override
  execute(C context, Event<E> event) => exec(context, event);
}

class ActionStandardAssign<C, E> extends ActionAssign<C, E> {
  const ActionStandardAssign(assignment) : super(assignment);

  @override
  C assign(C context, Event<E> event) => assignment(context, event);
}

class ActionStandardSend<E> extends ActionSend<E> {
  const ActionStandardSend(Event<E> event, to, {delay, id})
      : super(event, to, delay: delay, id: id);
}

class ActionStandardStartActivity<C, E> extends ActionStartActivity<C, E> {
  const ActionStandardStartActivity(activity) : super(activity);

  @override
  String toString() {
    return "${ActionStartActivity}(${activity})";
  }
}

class ActionStandardStopActivity<C, E> extends ActionStopActivity<C, E> {
  const ActionStandardStopActivity(activity) : super(activity);

  @override
  String toString() {
    return "${ActionStopActivity}(${activity})";
  }
}

class ActionStandardStartService<C, E> extends ActionStartService<C, E> {
  const ActionStandardStartService(service) : super(service);

  @override
  String toString() {
    return "${ActionStartService}(${service})";
  }
}

class ActionStandardStopService<C, E> extends ActionStopService<C, E> {
  const ActionStandardStopService(service) : super(service);

  @override
  String toString() {
    return "${ActionStopService}(${service})";
  }
}

class ActionStandardSendParent<C, E> extends ActionStandardSend<E> {
  const ActionStandardSendParent(Event<E> event) : super(event, '#_parent');

  @override
  String toString() {
    return "${ActionStandardSendParent}(${event})";
  }
}

class ActionStandardSendInternal<E> extends ActionStandardSend<E> {
  const ActionStandardSendInternal(Event<E> event) : super(event, '#_internal');

  @override
  String toString() {
    return "${ActionStandardSendInternal}(${event})";
  }
}

class ActionStandardSendDone<E> extends ActionStandardSendInternal<E> {
  const ActionStandardSendDone(Event<E> event) : super(event);

  @override
  String toString() {
    return "${ActionStandardSendDone}(${event})";
  }
}
