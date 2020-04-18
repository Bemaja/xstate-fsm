import 'interfaces.dart';
import 'log.dart';

class StandardSideEffects<C, E> extends SideEffects<C, E> {
  final SideEffects<C, E> parent;

  final Map<String, Action<C, E>> actions;
  final Map<String, ActionExecute<C, E>> executions;
  final Map<String, ActionAssign<C, E>> assignments;
  final Map<String, Activity<C, E>> activities;
  final Map<String, Service<C, E>> services;
  final Map<String, Guard<C, E>> guards;

  final ActionFactory<C, E> actionFactory;
  final GuardFactory<C, E> guardFactory;
  final ActivityFactory<C, E> activityFactory;

  final Validation validation;

  final Log log;

  const StandardSideEffects(
      this.actionFactory, this.activityFactory, this.guardFactory,
      {this.parent,
      this.actions = const {},
      this.assignments = const {},
      this.activities = const {},
      this.services = const {},
      this.executions = const {},
      this.guards = const {},
      this.validation,
      this.log = const Log()});

  List<Action<C, E>> getActions(dynamic action) {
    log.finer(this, () => "Fetching action ${action}");

    if (action == null) {
      return [];
    } else if (action is List) {
      return action
          .expand<Action<C, E>>((single) => getActions(single))
          .toList();
    } else if (action is Action<C, E>) {
      return [action];
    } else if (action is ActionExecution<C, E>) {
      return [actionFactory.createExecutionAction(action.toString(), action)];
    } else if (action is ActionAssignment<C, E>) {
      requireContext();
      return [actionFactory.createAssignmentAction(action)];
    } else if (action == null) {
      return [];
    } else if (action is String) {
      return [this[action]];
    }

    reportError("Action ${action} is not a valid action definition",
        data: {"action": action});

    return [];
  }

  Action<C, E> getAction(String action) {
    if (actions != null && actions.containsKey(action)) {
      return actions[action];
    } else if (executions != null && executions.containsKey(action)) {
      return executions[action];
    } else if (assignments != null && assignments.containsKey(action)) {
      requireContext();
      return assignments[action];
    } else if (parent != null) {
      return parent[action];
    }

    reportError("Action ${action} missing in action map",
        data: {"action": action});

    return actionFactory.createSimpleAction(action);
  }

  Action<C, E> operator [](String action) => getAction(action);

  List<Activity<C, E>> getActivities(dynamic activity) {
    log.finer(this, () => "Extracting activities from ${activity}");

    if (activity is List) {
      List<Activity<C, E>> activities = activity
          .expand<Activity<C, E>>((single) => getActivities(single))
          .toList();

      log.fine(this,
          () => "Extracted ${activities.length} activity from List config");

      log.fine(this, () => "Extracted ${activities}");

      return activities;
    } else if (activity is Activity<C, E>) {
      return [activity];
    } else if (activity == null) {
      return [];
    } else if (activity is String) {
      Activity<C, E> activityObject = getActivity(activity);

      log.finer(this, () => "Extracted ${activityObject} from String config");

      return [activityObject];
    }

    log.finer(this, () => "No valid activities");

    return [];
  }

  Activity<C, E> getActivity(String activity) {
    if (activities != null && activities.containsKey(activity)) {
      return activities[activity];
    } else if (parent != null) {
      return parent.getActivity(activity);
    }

    reportError("Activity ${activity} missing in activity map",
        data: {"activity": activity});

    return activityFactory.createEmptyActivity(activity);
  }

  List<Service<C, E>> getServices(dynamic service) {
    log.finer(this, () => "Extracting servies from ${service}");

    if (service is List) {
      List<Service<C, E>> services = service
          .expand<Service<C, E>>((single) => getServices(single))
          .toList();

      log.fine(
          this, () => "Extracted ${services.length} services from List config");

      log.fine(this, () => "Extracted ${services}");

      return services;
    } else if (service is Service<C, E>) {
      return [service];
    } else if (service == null) {
      return [];
    } else if (service is String) {
      Service<C, E> serviceObject = getService(service);

      log.finer(this, () => "Extracted ${serviceObject} from String config");

      return [serviceObject];
    }

    log.finer(this, () => "No valid services");

    reportError("Invalid ${service} definition", data: {"service": service});

    return [];
  }

  Service<C, E> getService(String service) {
    if (services != null && services.containsKey(service)) {
      return services[service];
    } else if (parent != null) {
      return parent.getService(service);
    }

    reportError("Service ${service} missing in service map",
        data: {"service": service});

    return null;
  }

  Guard<C, E> getGuard(dynamic guard) {
    if (guard == null) {
      return guardFactory.createMatchingGuard();
    } else if (guard is GuardCondition<C, E>) {
      guardFactory.createGuard(guard);
    } else if (guard is Guard<C, E>) {
      return guard;
    } else if (guards != null && guards.containsKey(guard)) {
      return guards[guard];
    } else if (parent != null) {
      return parent.getGuard(guard);
    }

    reportError("Guard ${guard} missing in guard map ${guards}",
        data: {"guard": guard});

    return guardFactory.createMatchingGuard();
  }

  void reportError(String message, {Map<String, dynamic> data}) {
    if (parent != null) {
      parent.reportError(message, data: data);

      return null;
    }
    if (validation != null) {
      validation.reportError(message, data: data);
    }
  }

  void requireContext() {
    if (parent != null) {
      parent.requireContext();

      return null;
    }
    if (validation != null) {
      validation.requireContext();
    }
  }
}
