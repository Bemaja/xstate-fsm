import 'interfaces.dart';

class StandardActionFactory<C, E> extends ActionFactory<C, E> {
  @override
  ActionStandard<C, E> createSimpleAction(String type) =>
      ActionStandard<C, E>(type);

  @override
  ActionAssign<C, E> createAssignmentAction(ActionAssignment<C, E> action) =>
      ActionStandardAssign<C, E>(action);

  @override
  ActionExecute<C, E> createExecutionAction(
          String type, ActionExecution<C, E> action) =>
      ActionStandardExecute<C, E>(type, action);

  @override
  Action<C, E> createSendAction(Service<C, E> service) =>
      ActionStandardSend<C, E>(service);

  @override
  Action<C, E> createStartActivity(Activity<C, E> activity) =>
      ActionStandardStartActivity<C, E>(activity);

  @override
  Action<C, E> createStopActivity(Activity<C, E> activity) =>
      ActionStandardStopActivity<C, E>(activity);

  @override
  Action<C, E> createStartService(Service<C, E> service) =>
      ActionStandardStartService<C, E>(service);

  @override
  Action<C, E> createStopService(Service<C, E> service) =>
      ActionStandardStopService<C, E>(service);
}

class ActionStandard<C, E> extends Action<C, E> {
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

class ActionStandardSend<C, E> extends ActionSend<C, E> {
  const ActionStandardSend(event, to, {delay, id})
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

class ActionStandardSendParent<C, E> extends ActionStandardSend<C, E> {
  const ActionStandardSendParent(event) : super(event, '#_parent');

  @override
  String toString() {
    return "${ActionStandardSendParent}(${event})";
  }
}

class ActionStandardSendInternal<C, E> extends ActionStandardSend<C, E> {
  const ActionStandardSendInternal(event) : super(event, '#_internal');

  @override
  String toString() {
    return "${ActionStandardSendInternal}(${event})";
  }
}
