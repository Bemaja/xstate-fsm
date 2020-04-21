import 'interfaces.dart';
import 'log.dart';

class ActionCollector<C, E> {
  final StateTreeNode<C, E> tree;

  final Log log;

  const ActionCollector(this.tree, {this.log = const Log()});

  List<Action> onEntry(C context) =>
      tree.walkStateTree<Action>((StateTreeNode<C, E> treeNode) {
        log.finest(
            this,
            () =>
                "Collecting entry actions ${treeNode.node.onEntry} on ${treeNode.node}");
        return treeNode.node.onEntry +
            treeNode.node.onActiveStart +
            collectPotentialDoneEvents(context) +
            treeNode.node.onServiceStart;
      });

  List<Action> collectPotentialDoneEvents(C context) =>
      tree.walkStateTree<Action>((StateTreeNode<C, E> treeNode) =>
          treeNode.collectPotentialDoneEvents(context));

  List<Action> get onExit => tree.walkStateTree<Action>(
      (StateTreeNode<C, E> treeNode) => treeNode.node.onExit);

  List<Activity<C, E>> get activities => tree.walkStateTree<Activity<C, E>>(
      (StateTreeNode<C, E> treeNode) => treeNode.node.onActive);

  List<Service<C, E>> get services => tree.walkStateTree<Service<C, E>>(
      (StateTreeNode<C, E> treeNode) => treeNode.node.services);

  List<Action> entriesFromTransition(StateTreeNode<C, E> oldTree, C context) =>
      tree.walkStateTree<Action>((StateTreeNode<C, E> treeNode) {
        if (oldTree.hasBranch(treeNode.node)) {
          log.finer(
              this,
              () =>
                  "${treeNode.node} was active before -> not entering and collecting entry actions");
          return [];
        } else {
          List<Action> onEntry = treeNode.node.onEntry;
          List<Action> onActive = treeNode.node.onActiveStart;
          List<Action> onDone = collectPotentialDoneEvents(context);
          List<Action> services = treeNode.node.onServiceStart;

          log.finer(this,
              () => "Collected entry actions ${onEntry} on ${treeNode.node}");

          log.finer(
              this,
              () =>
                  "Collected activity start actions ${onActive} on ${treeNode.node}");

          log.finer(
              this,
              () =>
                  "Collected service start actions ${services} on ${treeNode.node}");

          return onEntry + onActive + onDone + services;
        }
      });

  List<Action> exitsFromTransition(StateTreeNode<C, E> oldTree) =>
      oldTree.walkStateTree<Action>((StateTreeNode<C, E> treeNode) =>
          tree.hasBranch(treeNode.node)
              ? []
              : treeNode.node.onExit +
                  treeNode.node.onActiveStop +
                  treeNode.node.onServiceStop);
}

class StandardStateTreeLeaf<C, E> extends StateTreeLeaf<C, E> {
  final Log log;

  const StandardStateTreeLeaf({this.log = const Log()});

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

  @override
  bool get isFinal => false;

  @override
  bool get hasTransientTransition => false;

  dynamic getDoneData(C context) => null;

  bool hasBranch(StateNode<C, E> matchingNode) => false;

  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode) => null;

  @override
  List<String> toAscii({num level = 0, String key = ""}) =>
      ["|-o ${key}".padLeft(level + key.length + 3)];

  @override
  dynamic toStateValue() =>
      throw Exception("Leafs do not contribute to state value.");
}

class StandardStateTreeParallel<C, E> extends StateTreeParallel<C, E> {
  final List<StateTreeNode<C, E>> children;

  final Log log;

  const StandardStateTreeParallel(this.children, {this.log = const Log()});

  @override
  bool get isFinal => children.every((child) => child.node.isFinal);

  @override
  bool get hasTransientTransition =>
      children.any((child) => child.hasTransientTransition);

  dynamic getDoneData(C context) => null;

  // TODO: implement
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

class StandardStateTreeCompound<C, E> extends StateTreeCompound<C, E> {
  final StateTreeNode<C, E> child;

  final Log log;

  const StandardStateTreeCompound(this.child, {this.log = const Log()});

  @override
  bool get isFinal => child.node.isFinal;

  @override
  bool get hasTransientTransition => child.hasTransientTransition;

  dynamic getDoneData(C context) => child.node.data is DataMapper<C>
      ? child.node.data(context)
      : child.node.data;

  // TODO: implement
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

class StandardStateTreeNode<C, E> extends StateTreeNode<C, E> {
  final StateFactory<C, E> stateFactory;
  final Log log;

  const StandardStateTreeNode(node, type, this.stateFactory,
      {this.log = const Log()})
      : super(node, type);

  @override
  List<Action> collectPotentialDoneEvents(C context) {
    if (type.isFinal) {
      Action done = node.raiseDone(type.getDoneData(context));
      log.finest(this, () => "Reached final state, eliciting ${done}");
      return [done];
    }
    return <Action>[];
  }

  @override
  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) {
    log.finest(this, () => "Walk tree delivering node ${node} to walker");
    return walker(this) + type.walkStateTree<T>(walker);
  }

  @override
  Transition<C, E> resolveTransition(State<C, E> state, Event<E> event) {
    log.fine(this, () => "Resolving transition in response to ${event}");

    return type.transition(node, state, event);
  }

  State<C, E> state({C context}) {
    ActionCollector<C, E> collector = ActionCollector(this);
    log.finer(this, () => "Collected initial actions ${collector.onEntry}");
    return stateFactory.createState(this, collector.onEntry(context), context,
        activities: {for (var a in collector.activities) a.type: true});
  }

  State<C, E> _buildNewState(StateTreeNode<C, E> tree, List<Action> actions,
      C oldContext, Event<E> event,
      {Map<String, bool> activities = const {}, List<Service<C, E>> children}) {
    return stateFactory.createState(
        tree,
        actions.where((action) => !(action is ActionAssign<C, E>)).toList(),
        actions.fold<C>(oldContext, (C oldContext, Action action) {
          if (action is ActionAssign<C, E>) {
            log.finest(
                this, () => "Applying $action since it is an assignment");
            return action.assign(oldContext, event);
          } else {
            return oldContext;
          }
        }),
        activities: activities,
        children: children,
        changed: !actions.isEmpty ||
            actions.fold<bool>(false, (bool changed, Action action) {
              print(action.toString());
              return changed || (action is ActionAssign<C, E>);
            }));
  }

  State<C, E> _microTransition(State<C, E> state, Event<E> originalEvent,
      {Event<E> event}) {
    State<C, E> newState = this.transition(state, event);

    return _buildNewState(newState.value, state.actions + newState.actions,
        newState.context, originalEvent,
        activities: newState.activities, children: newState.children);
  }

  @override
  State<C, E> transition(State<C, E> state, Event<E> event) {
    Transition<C, E> targetTransition = resolveTransition(state, event);
    State<C, E> newState;

    if (targetTransition is NoTransition) {
      log.fine(this, () => "Resolved to NO TRANSITION in response to ${event}");
      return _buildNewState(state.value, [], state.context, event,
          activities: state.activities, children: state.children);
    }

    if (targetTransition.getTarget == null) {
      log.fine(this, () => "Resolved to NO TRANSITION as getTarget is Null");

      newState = _buildNewState(
          state.value, targetTransition.actions, state.context, event,
          activities: state.activities, children: state.children);
    } else {
      StateNode<C, E> entryNode = targetTransition.getTarget();

      if (entryNode == null) {
        log.fine(this, () => "Resolved to NO TRANSITION as target is Null");

        return _buildNewState(
            state.value, targetTransition.actions, state.context, event);
      } else {
        log.fine(
            this,
            () =>
                "Selected target node ${entryNode} for entering after transition");

        StateTreeNode<C, E> entryTree =
            entryNode.transitionFromTree(state.value);

        log.fine(
            this, () => "Resolved to \n${entryTree}\n in response to ${event}");

        ActionCollector<C, E> actionCollector =
            ActionCollector<C, E>(entryTree);
        List<Action> entryActions =
            actionCollector.entriesFromTransition(state.value, state.context);
        List<Action> exitActions =
            actionCollector.exitsFromTransition(state.value);

        log.finer(
            this,
            () =>
                "Entry actions ${entryActions} collected from \n${entryTree}\n in response to ${event}");
        log.finer(
            this,
            () =>
                "Exit actions ${exitActions} collected from \n${entryTree}\n in response to ${event}");

        List<Action> allActions =
            exitActions + targetTransition.actions + entryActions;

        log.finer(this, () => "Previous activities were ${state.activities}");
        log.finer(
            this, () => "New activities are ${actionCollector.activities}");

        newState = _buildNewState(entryTree, allActions, state.context, event,
            activities: {
              for (var a in state.activities.keys) a: false,
              for (var b in actionCollector.activities) b.type: true
            },
            children: actionCollector.services);
      }
    }

    log.finer(this, () => "Handling potential micro transitions");

    if (!state.value.type.isFinal && state.value.hasTransientTransition) {
      log.finer(this, () => "Handling potential transient transition");
      newState = _microTransition(newState, event);
    }

    return newState;
  }

  @override
  bool matches(StateNode<C, E> matchingNode) => matchingNode == node;

  @override
  bool hasBranch(StateNode<C, E> matchingNode) =>
      matches(matchingNode) || type.hasBranch(matchingNode);

  @override
  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode) =>
      matches(matchingNode) ? this : type.getBranch(matchingNode);

  @override
  List<String> toAscii({num level = 0}) =>
      type.toAscii(level: level + 1, key: node.key);

  @override
  dynamic toStateValue() => type.toStateValue();

  @override
  bool get isLeaf => type is StateTreeLeaf<C, E>;

  @override
  bool get hasTransientTransition =>
      node.hasTransientTransition || type.hasTransientTransition;

  dynamic toOptionalStateValue() => isLeaf ? node.key : toStateValue();

  @override
  String toString() {
    String tree = toAscii().join("\n");
    return "${StateTreeNode}(${node.id}) of tree \n${tree}";
  }
}

class StandardStateTreeFactory<C, E> extends StateTreeFactory<C, E> {
  final StateFactory<C, E> stateFactory;

  const StandardStateTreeFactory(this.stateFactory);

  @override
  StateTreeNode<C, E> createTreeNode(
          StateNode<C, E> node, StateTreeType<C, E> type) =>
      StandardStateTreeNode<C, E>(node, type, stateFactory);

  @override
  StateTreeType<C, E> createTreeNodeType({List<StateTreeNode<C, E>> children}) {
    if (children == null) {
      return StandardStateTreeLeaf<C, E>();
    }

    switch (children.length) {
      case 0:
        return StandardStateTreeLeaf<C, E>();
      case 1:
        return StandardStateTreeCompound<C, E>(children[0]);
      default:
        return StandardStateTreeParallel<C, E>(children);
    }
  }
}
