import 'actions.dart';
import 'activities.dart';
import 'event.dart';
import 'log.dart';
import 'node.dart';
import 'state.dart';
import 'transitions.dart';

abstract class StateTreeType<C, E> {
  const StateTreeType();

  Transition<C, E> transition(
      StateNode<C, E> node, State<C, E> state, Event<E> event);

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker);

  List<String> toAscii({num level = 0, String key = ""});

  dynamic toStateValue();

  bool hasBranch(StateNode<C, E> matchingNode);

  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode);

  bool get isLeaf;
}

class StateTreeLeaf<C, E> extends StateTreeType<C, E> {
  final Log log;

  const StateTreeLeaf({this.log = const Log()});

  @override
  Transition<C, E> transition(
          StateNode<C, E> node, State<C, E> state, Event<E> event) =>
      node.next(state, event);

  @override
  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) {
    log.finest(this, () => "Walk tree ended => Reached leaf");
    return const [];
  }

  @override
  bool get isLeaf => true;

  bool hasBranch(StateNode<C, E> matchingNode) => false;

  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode) => null;

  @override
  List<String> toAscii({num level = 0, String key = ""}) =>
      ["|-o ${key}".padLeft(level + key.length + 3)];

  @override
  dynamic toStateValue() =>
      throw Exception("Leafs do not contribute to state value.");
}

class StateTreeParallel<C, E> extends StateTreeType<C, E> {
  final List<StateTreeNode<C, E>> children;

  final Log log;

  const StateTreeParallel(this.children, {this.log = const Log()});

  //implement
  @override
  Transition<C, E> transition(
          StateNode<C, E> node, State<C, E> state, Event<E> event) =>
      NoTransition<C, E>();

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) {
    List<T> result =
        children.expand<T>((child) => child.walkStateTree<T>(walker)).toList();
    log.finest(
        this, () => "Walking tree over ${children.length} parallel children");
    return result;
  }

  @override
  bool get isLeaf =>
      children.fold(true, (result, child) => result && child.isLeaf);

  bool hasBranch(StateNode<C, E> matchingNode) =>
      children.any((child) => child.hasBranch(matchingNode));

  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode) {
    for (var i = 0; i < children.length; i++) {
      if (children[i].matches(matchingNode)) {
        return children[i];
      } else if (children[i].hasBranch(matchingNode)) {
        return children[i].getBranch(matchingNode);
      }
    }
    return null;
  }

  List<String> toAscii({num level = 0, String key = ""}) => children
      .expand<String>((child) => ([
            "|- ${key}".padLeft(level + key.length + 3)
          ] +
          child.toAscii(level: level + 1)))
      .toList();

  @override
  dynamic toStateValue() => this.children.map((child) => child.toStateValue());
}

class StateTreeCompound<C, E> extends StateTreeType<C, E> {
  final StateTreeNode<C, E> child;

  final Log log;

  const StateTreeCompound(this.child, {this.log = const Log()});

  // implement
  @override
  Transition<C, E> transition(
      StateNode<C, E> node, State<C, E> state, Event<E> event) {
    Transition<C, E> childTransition = child.resolveTransition(state, event);
    if (childTransition is NoTransition<C, E>) {
      return node.next(state, event);
    }
    return childTransition;
  }

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) {
    log.finest(this, () => "Walking tree to single child ${child.node}");
    return child.walkStateTree<T>(walker);
  }

  @override
  bool get isLeaf => child.isLeaf;

  bool hasBranch(StateNode<C, E> matchingNode) => child.hasBranch(matchingNode);

  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode) {
    if (child.matches(matchingNode)) {
      return child;
    }
    return null;
  }

  @override
  List<String> toAscii({num level = 0, String key = ""}) =>
      ["|- ${key}".padLeft(level + key.length + 3)] +
      child.toAscii(level: level + 1);

  @override
  dynamic toStateValue() =>
      child.isLeaf ? child.node.key : child.toStateValue();
}

typedef StateTreeWalk<T, C, E> = List<T> Function(StateNode<C, E>);

class StateTreeNode<C, E> {
  final StateNode<C, E> node;
  final StateTreeType<C, E> type;

  final Log log;

  const StateTreeNode(this.node, this.type, {this.log = const Log()});

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) {
    log.finest(this, () => "Walk tree delivering node ${node} to walker");
    return walker(node) + type.walkStateTree<T>(walker);
  }

  Transition<C, E> resolveTransition(State<C, E> state, Event<E> event) {
    log.fine(this, () => "Resolving transition in response to ${event}");

    return type.transition(node, state, event);
  }

  State<C, E> _buildNewState(StateTreeNode<C, E> tree,
      List<Action<C, E>> actions, C oldContext, Event<E> event,
      {Map<String, bool> stoppedActivities = const {},
      List<Activity<C, E>> startedActivities = const []}) {
    return State(tree,
        context:
            actions.fold<C>(oldContext, (C oldContext, Action<C, E> action) {
          log.finest(this, () => "Applying $action if it is an assignment");
          if (action is ActionAssign<C, E>) {
            return action.assign(oldContext, event);
          } else {
            return oldContext;
          }
        }),
        actions:
            actions.where((action) => !(action is ActionAssign<C, E>)).toList(),
        activities: {
          for (var a in stoppedActivities.keys) a: false,
          for (var b in startedActivities) b.type: true
        },
        changed: !actions.isEmpty ||
            actions.fold<bool>(
                false,
                (bool changed, Action<C, E> action) =>
                    changed || (action is ActionAssign)));
  }

  State<C, E> transition(State<C, E> state, Event<E> event) {
    Transition<C, E> targetTransition = resolveTransition(state, event);

    if (targetTransition is NoTransition) {
      log.fine(this, () => "Resolved to NO TRANSITION in response to ${event}");

      // TODO: Check if sufficient (changed needs rewrite?). Probably just clone.
      return _buildNewState(state.value, [], state.context, event);
    } else {
      if (targetTransition.getTarget == null) {
        log.fine(this, () => "Resolved to NO TRANSITION as getTarget is Null");

        return _buildNewState(
            state.value, targetTransition.actions, state.context, event);
      }
      StateNode<C, E> entryNode = targetTransition.getTarget();

      if (entryNode == null) {
        log.fine(this, () => "Resolved to NO TRANSITION as target is Null");

        return _buildNewState(
            state.value, targetTransition.actions, state.context, event);
      }

      log.fine(
          this,
          () =>
              "Selected target node ${entryNode} for entering after transition");

      StateTreeNode<C, E> entryTree = entryNode.transitionFromTree(state.value);

      log.fine(
          this, () => "Resolved to \n${entryTree}\n in response to ${event}");

      ActionCollector<C, E> actionCollector = ActionCollector<C, E>(entryTree);
      List<Action<C, E>> entryActions =
          actionCollector.entriesFromTransition(state.value);
      List<Action<C, E>> exitActions =
          actionCollector.exitsFromTransition(state.value);

      log.finer(
          this,
          () =>
              "Entry actions ${entryActions} collected from \n${entryTree}\n in response to ${event}");
      log.finer(
          this,
          () =>
              "Exit actions ${exitActions} collected from \n${entryTree}\n in response to ${event}");

      List<Action<C, E>> allActions =
          exitActions + targetTransition.actions + entryActions;

      log.finer(this, () => "Previous activities were ${state.activities}");
      log.finer(this, () => "New activities are ${actionCollector.activities}");

      return _buildNewState(entryTree, allActions, state.context, event,
          stoppedActivities: state.activities,
          startedActivities: actionCollector.activities);
    }
  }

  bool matches(StateNode<C, E> matchingNode) => matchingNode == node;

  bool hasBranch(StateNode<C, E> matchingNode) =>
      matches(matchingNode) || type.hasBranch(matchingNode);

  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode) =>
      matches(matchingNode) ? this : type.getBranch(matchingNode);

  List<String> toAscii({num level = 0}) =>
      type.toAscii(level: level + 1, key: node.key);

  dynamic toStateValue() => type.toStateValue();

  bool get isLeaf => type is StateTreeLeaf<C, E>;

  dynamic toOptionalStateValue() => isLeaf ? node.key : toStateValue();

  @override
  String toString() {
    String tree = toAscii().join("\n");
    return "${StateTreeNode}(${node.id}) of tree \n${tree}";
  }
}
