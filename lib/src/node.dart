import 'interfaces.dart';
import 'log.dart';

class TreeAccess<C, E> {
  final LazyAccess<StateNode<C, E>> _getParent;
  final LazyAccess<StateNode<C, E>> getRoot;

  const TreeAccess(this.getRoot, {getParent}) : this._getParent = getParent;

  StateNode<C, E> get parent => _getParent == null ? _getParent : _getParent();
  StateNode<C, E> get root => getRoot == null ? getRoot : getRoot();

  List<String> get path => parent == null ? [] : parent.path;

  bool get hasParent => _getParent == null;

  TreeAccess<C, E> clone({LazyAccess<StateNode<C, E>> newGetParent}) =>
      TreeAccess<C, E>(this.getRoot, getParent: newGetParent);
}

class StandardStateNode<C, E> extends StateNode<C, E> {
  final StateTreeFactory<C, E> treeFactory;
  final TreeAccess<C, E> tree;
  final SideEffects<C, E> sideEffects;

  final bool strict;

  final Log log;

  const StandardStateNode(this.treeFactory,
      {config,
      id,
      delimiter,
      path,
      type,
      this.tree,
      this.sideEffects,
      transitions = const {},
      onEntry = const [],
      onExit = const [],
      onActive = const [],
      onActiveStart = const [],
      onActiveStop = const [],
      services = const [],
      onServiceStart = const [],
      onServiceStop = const [],
      data,
      initialStateTree = null,
      context = null,
      this.strict = false,
      this.log = const Log()})
      : assert(!strict || config == null || id != "",
            "You provided no ID for the machine!"),
        super(
            id: id,
            config: config,
            delimiter: delimiter,
            path: path,
            type: type,
            transitions: transitions,
            onEntry: onEntry,
            onExit: onExit,
            onActive: onActive,
            onActiveStart: onActiveStart,
            onActiveStop: onActiveStop,
            services: services,
            onServiceStart: onServiceStart,
            onServiceStop: onServiceStop,
            data: data,
            initialStateTree: initialStateTree,
            context: context);

  StateNode<C, E> get parent => tree.parent;
  StateNode<C, E> get root => tree.root;

  @override
  bool get isFinal => type.isFinal;

  @override
  Action operator [](String action) => sideEffects[action];

  @override
  String get key => type.key;

  @override
  State<C, E> get initialState {
    log.finest(this, () => "Determine initial state");
    return this.initialStateTreeNode.state(context: context);
  }

  StateTreeNode<C, E> get initialStateTreeNode {
    StateTreeNode<C, E> initial =
        treeFactory.createTreeNode(this, initialStateTree);
    log.finest(this, () => "Initial tree is \n${initial}\n");
    return initial;
  }

  @override
  StateTreeNode<C, E> transitionFromTree(StateTreeNode<C, E> oldTree,
      {StateTreeNode<C, E> childBranch}) {
    StateTreeNode<C, E> thisAsChildBranch;
    if (childBranch == null) {
      // Entry into target node
      if (oldTree.hasBranch(this)) {
        log.fine(this, () => "Node was active in \n${oldTree}\n");

        thisAsChildBranch = oldTree.getBranch(this);
      } else {
        log.fine(
            this,
            () =>
                "Selected child branch to be initial branch \n${initialStateTreeNode}\n");

        thisAsChildBranch = initialStateTreeNode;
      }
    } else {
      thisAsChildBranch = treeFactory.createTreeNode(
          this,
          type.transitionFromTree(initialStateTreeNode,
              oldTree: oldTree, childBranch: childBranch));

      log.fine(
          this, () => "Selected child branch to be \n${thisAsChildBranch}\n");
    }
    return parent == null
        ? thisAsChildBranch
        : parent.transitionFromTree(oldTree, childBranch: thisAsChildBranch);
  }

  StateNode<C, E> selectTargetNode(String key) {
    StateNode<C, E> target = type.selectTargetNode(key) ?? this;

    log.fine(this, () => "Selecting node ${key} as \"${target}\"");

    return target;
  }

  StateTreeNode<C, E> select(String key, {StateTreeNode<C, E> childBranch}) {
    log.fine(this,
        () => "Selecting branch ${key} with child branch \"${childBranch}\"");

    StateTreeNode<C, E> thisAsChildBranch = treeFactory.createTreeNode(
        this, type.selectStateTree(key: key, childBranch: childBranch));

    log.fine(this, () => "Selected child branch \n${thisAsChildBranch}");

    if (parent == null) {
      return thisAsChildBranch;
    }

    StateTreeNode<C, E> fullBranch =
        parent.select(type.key, childBranch: thisAsChildBranch);

    log.fine(this,
        () => "Selected full branch \n${fullBranch}\nfrom parent ${parent}");

    return fullBranch;
  }

  @override
  State<C, E> transitionUntyped(dynamic state, dynamic event) {
    State<C, E> typedState;
    Event<E> typedEvent;

    if (state is String) {
      typedState = this.select(state).state(context: context);
    } else if (state is State<C, E>) {
      typedState = state;
    } else {
      throw Exception(
          "Deriving state from ${state.runtimeType} is not (yet) supported.");
    }

    if (event is String) {
      typedEvent = Event<E>(event);
    } else if (event is Event<E>) {
      typedEvent = event;
    } else {
      throw Exception(
          "Deriving events from ${event.runtimeType} is not (yet) supported.");
    }

    log.fine(
        this,
        () =>
            "Transitioning from ${state} as ${typedState} on ${event} as ${typedEvent}");

    return transition(typedState, typedEvent);
  }

  @override
  State<C, E> transition(State<C, E> state, Event<E> event) {
    log.fine(this, () => "Transitioning on ${event}");

    return state.value.transition(state, event);
  }

  @override
  Transition<C, E> next(State<C, E> state, Event<E> event) {
    var matchingTransitions = _getTransitionFor(event).skipWhile((transition) {
      bool doesNotMatch = transition.doesNotMatch(state.context, event);
      log.finest(
          this,
          () =>
              "Transition $transition ${doesNotMatch ? 'does not match' : 'matches'} context ${state.context} and event ${event}");
      return doesNotMatch;
    });
    log.fine(this, () => "${matchingTransitions.length} matching transitions");
    if (!matchingTransitions.isEmpty) {
      log.fine(this, () => "Returning first transition");
      return matchingTransitions.first;
    }
    log.fine(this, () => "Returning no transitions");
    return NoTransition<C, E>();
  }

  @override
  bool get hasTransientTransition => transitions.containsKey(null);

  List<Transition<C, E>> _getTransitionFor(Event<E> event) {
    if (event == null) {
      if (hasTransientTransition) {
        log.fine(this, () => "Returning transient transition");
        return transitions[event];
      }
      return <Transition<C, E>>[];
    }
    if (!transitions.containsKey(event.name)) {
      return <Transition<C, E>>[];
    }
    return transitions[event.name];
  }

  Action raiseDone(dynamic data) => sideEffects.createDone(id, data);

  @override
  String toString() => "${StateNode}(${id})";
}
