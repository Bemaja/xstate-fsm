import 'actions.dart';
import 'activities.dart';
import 'event.dart';
import 'guards.dart';
import 'log.dart';
import 'node.dart';
import 'tree.dart';

class Transition<C, E> {
  final LazyAccess<StateNode<C, E>> getTarget;
  final List<Action<C, E>> actions;
  final Guard<C, E> condition;

  final Log log;

  const Transition(
      {this.getTarget, this.actions, this.condition, this.log = const Log()});

  bool doesNotMatch(C context, Event<E> event) {
    return condition != null && !condition.matches(context, event);
  }
}

class NoTransition<C, E> extends Transition<C, E> {
  bool doesNotMatch(C context, Event<E> event) => false;
}

class ActionCollector<C, E> {
  final StateTreeNode<C, E> tree;

  final Log log;

  const ActionCollector(this.tree, {this.log = const Log()});

  List<Action<C, E>> get onEntry =>
      tree.walkStateTree<Action<C, E>>((StateNode<C, E> node) {
        log.finest(
            this, () => "Collecting entry actions ${node.onEntry} on ${node}");
        return node.onEntry;
      });

  List<Action<C, E>> get onExit =>
      tree.walkStateTree<Action<C, E>>((StateNode<C, E> node) => node.onExit);

  List<Activity<C, E>> get activities => tree
      .walkStateTree<Activity<C, E>>((StateNode<C, E> node) => node.onActive);

  List<Action<C, E>> entriesFromTransition(StateTreeNode<C, E> oldTree) =>
      tree.walkStateTree<Action<C, E>>((StateNode<C, E> node) {
        if (oldTree.hasBranch(node)) {
          log.finer(
              this,
              () =>
                  "${node} was active before -> not entering and collecting entry actions");
          return [];
        } else {
          List<Action<C, E>> onEntry = node.onEntry;
          List<Action<C, E>> onActive = node.onActive
              .map<Action<C, E>>((activity) => ActionStart<C, E>(activity))
              .toList();

          log.finer(
              this, () => "Collected entry actions ${onEntry} on ${node}");

          log.finer(this,
              () => "Collected activity start actions ${onActive} on ${node}");

          return onEntry + onActive;
        }
      });

  List<Action<C, E>> exitsFromTransition(StateTreeNode<C, E> oldTree) =>
      oldTree.walkStateTree<Action<C, E>>((StateNode<C, E> node) => tree
              .hasBranch(node)
          ? []
          : node.onExit +
              node.onActive
                  .map<Action<C, E>>((activity) => ActionStop<C, E>(activity))
                  .toList());
}
