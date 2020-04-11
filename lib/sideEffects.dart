import 'actions.dart';
import 'activities.dart';
import 'guards.dart';
import 'log.dart';

class SideEffects<C, E> {
  final SideEffects<C, E> parent;

  final Map<String, Action<C, E>> actions;
  final Map<String, ActionExecute<C, E>> executions;
  final Map<String, ActionAssign<C, E>> assignments;
  final Map<String, Activity<C, E>> activities;
  final Map<String, Guard<C, E>> guards;

  final bool _ifStrict;
  final Log log;

  const SideEffects(
      {this.parent,
      this.actions = const {},
      this.assignments = const {},
      this.activities = const {},
      this.executions = const {},
      this.guards = const {},
      strict = false,
      this.log = const Log()})
      : this._ifStrict = !strict;

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
      return [ActionExecute<C, E>(action.toString(), action)];
    } else if (action is ActionAssignment<C, E>) {
      return [ActionAssign<C, E>(action)];
    } else if (action == null) {
      return [];
    } else if (action is String) {
      return [this[action]];
    }
    assert(_ifStrict, "Action ${action} is not a valid action definition");

    return [];
  }

  Action<C, E> getAction(String action) {
    if (actions != null && actions.containsKey(action)) {
      return actions[action];
    } else if (executions != null && executions.containsKey(action)) {
      return executions[action];
    } else if (assignments != null && assignments.containsKey(action)) {
      return assignments[action];
    } else if (parent != null) {
      return parent[action];
    }

    assert(_ifStrict, "Action ${action} missing in action map");
    return Action<C, E>(action);
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

    assert(_ifStrict, "Activity ${activity} missing in activity map");
    return Activity<C, E>(activity, (context, activity) => () => {});
  }

  Guard<C, E> getGuard(String guard) {
    if (guard == null) {
      return GuardMatches<C, E>();
    } else if (guards != null && guards.containsKey(guard)) {
      return guards[guard];
    } else if (parent != null) {
      return parent.getGuard(guard);
    }

    assert(_ifStrict, "Guard ${guard} missing in guard map ${guards}");
    return GuardMatches<C, E>();
  }
}
