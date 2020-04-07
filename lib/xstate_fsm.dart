import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'activities.dart';

//***********************************************
// ACTIONS
//***********************************************

class Action<C, E> extends Equatable {
  final String type;

  const Action(String this.type);

  @override
  List<Object> get props => [type];

  @override
  String toString() {
    return "ActionObject of \"${type}\"";
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

enum ActionType { Action, Execution, Assignment }

//***********************************************
// GUARDS
//***********************************************

typedef GuardCondition<C, E> = bool Function(C context, Event<E> event);

abstract class Guard<C, E> {
  final String type;

  const Guard(String this.type);

  matches(C context, Event<E> event);
}

class GuardConditional<C, E> extends Guard<C, E> {
  final GuardCondition<C, E> condition;

  const GuardConditional(String type, GuardCondition<C, E> this.condition)
      : super(type);

  @override
  matches(C context, Event<E> event) => condition(context, event);
}

class GuardMatches<C, E> extends Guard<C, E> {
  const GuardMatches() : super('xstate.matches');

  @override
  matches(C context, Event<E> event) => true;
}

class GuardMap<C, E> {}

//***********************************************
// STATE / EVENT / CONTEXT
//***********************************************

class State<C, E> {
  final StateTreeNode<C, E> value;
  final List<Action<C, E>> actions;
  final C context;
  final bool changed;
  final StateMatcher matches;
  final Map<String, bool> activities;
  final List<dynamic> children;

  const State(this.value,
      {this.context = null,
      this.actions = const [],
      this.activities = const {},
      this.children = const [],
      this.changed = false,
      this.matches});

  static StateMatcher createStateMatcher(String value) {
    return (String stateValue) => stateValue == value;
  }

  // matches: (String stateValue) => stateValue == initial)
}

class Event<E> {
  final String type;
  final E event;

  const Event(this.type, {this.event});

  @override
  String toString() => "${Event}(${type})";
}

abstract class ContextFactory<C> {
  C fromMap(Map<String, dynamic> map);

  C copy(C original);
}

//***********************************************
// TRANSITIONS
//***********************************************

class Transition<C, E> {
  final LazyAccess<StateNode<C, E>> getTarget;
  final List<Action<C, E>> actions;
  final Guard<C, E> condition;

  const Transition({this.getTarget, this.actions, this.condition});

  bool doesNotMatch(C context, Event<E> event) {
    return condition != null && !condition.matches(context, event);
  }
}

class NoTransition<C, E> extends Transition<C, E> {
  bool doesNotMatch(C context, Event<E> event) => false;
}

class ActionCollector<C, E> {
  final StateTreeNode<C, E> tree;

  const ActionCollector(this.tree);

  List<Action<C, E>> get onEntry =>
      tree.walkStateTree<Action<C, E>>((StateNode<C, E> node) => node.onEntry);

  List<Action<C, E>> get onExit =>
      tree.walkStateTree<Action<C, E>>((StateNode<C, E> node) => node.onExit);

  List<Activity<C, E>> get activities => tree
      .walkStateTree<Activity<C, E>>((StateNode<C, E> node) => node.onActive);

  List<Action<C, E>> entriesFromTransition(StateTreeNode<C, E> oldTree) =>
      tree.walkStateTree<Action<C, E>>((StateNode<C, E> node) =>
          oldTree.hasBranch(node) ? [] : node.onEntry);

  List<Action<C, E>> exitsFromTransition(StateTreeNode<C, E> oldTree) =>
      tree.walkStateTree<Action<C, E>>(
          (StateNode<C, E> node) => oldTree.hasBranch(node) ? [] : node.onExit);
}

//***********************************************
// STATE TREE
//***********************************************

typedef StateMatcher = bool Function(String);

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
  const StateTreeLeaf();

  @override
  Transition<C, E> transition(
          StateNode<C, E> node, State<C, E> state, Event<E> event) =>
      node.next(state, event);

  @override
  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) => const [];

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

  const StateTreeParallel(this.children);

  //implement
  @override
  Transition<C, E> transition(
          StateNode<C, E> node, State<C, E> state, Event<E> event) =>
      NoTransition<C, E>();

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) =>
      children.expand<T>((child) => child.walkStateTree<T>(walker)).toList();

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

  const StateTreeCompound(this.child);

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

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) =>
      child.walkStateTree<T>(walker);

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

  final Logger _log;

  const StateTreeNode(this.node, this.type, {log}) : this._log = log;

  log(Level logLevel, dynamic message) =>
      _log != null ? _log.log(logLevel, message) : null;

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker) =>
      walker(node) + type.walkStateTree<T>(walker);

  Transition<C, E> resolveTransition(State<C, E> state, Event<E> event) {
    log(Level.FINE,
        () => "${toString()}\n resolving transition in response to ${event}");

    return type.transition(node, state, event);
  }

  State<C, E> transition(State<C, E> state, Event<E> event) {
    Transition<C, E> targetTransition = resolveTransition(state, event);

    if (targetTransition is NoTransition) {
      log(
          Level.FINE,
          () =>
              "${toString()}\n resolved to NO TRANSITION in response to ${event}");

      // TODO: Check if sufficient (changed needs rewrite?). Probably just clone.
      return state;
    } else {
      StateNode<C, E> entryNode = targetTransition.getTarget();

      log(
          Level.FINE,
          () =>
              "${toString()}\n selected target node ${entryNode} for entering after transition");

      StateTreeNode<C, E> entryTree = entryNode.transitionFromTree(state.value);

      log(
          Level.FINE,
          () =>
              "${toString()}\n resolved to \n${entryTree}\n in response to ${event}");

      ActionCollector<C, E> actionCollector = ActionCollector<C, E>(entryTree);
      List<Action<C, E>> entryActions =
          actionCollector.entriesFromTransition(state.value);
      List<Action<C, E>> exitActions =
          actionCollector.exitsFromTransition(state.value);

      List<Action<C, E>> allActions =
          exitActions + targetTransition.actions + entryActions;

      return State(entryTree,
          context: allActions.fold<C>(state.context,
              (C oldContext, Action<C, E> action) {
            if (action is ActionAssign<C, E>) {
              return action.assign(oldContext, event);
            } else {
              return oldContext;
            }
          }),
          actions:
              allActions.where((action) => !(action is ActionAssign)).toList(),
          activities: {for (var a in actionCollector.activities) a.type: true},
          changed: !allActions.isEmpty ||
              allActions.fold<bool>(
                  false,
                  (bool changed, Action<C, E> action) =>
                      changed || (action is ActionAssign)));
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

//***********************************************
// MACHINE
//***********************************************

abstract class NodeType<C, E> {
  final String key;
  final bool _strict;

  const NodeType(this.key, {strict = false}) : this._strict = strict;

  bool get isLeafNode => true;
  bool get ifStrict => !_strict;

  StateTreeType<C, E> transitionFromTree(
          StateTreeNode<C, E> initialStateTreeNode,
          {StateTreeNode<C, E> oldTree,
          StateTreeNode<C, E> childBranch}) =>
      StateTreeLeaf<C, E>();

  StateTreeType<C, E> selectStateTree(
          {String key, StateTreeNode<C, E> childBranch}) =>
      StateTreeLeaf<C, E>();

  StateNode<C, E> selectTargetNode(String key) => null;
}

class NodeTypeAtomic<C, E> extends NodeType<C, E> {
  const NodeTypeAtomic(key, {strict = false}) : super(key, strict: strict);
}

class NodeTypeFinal<C, E> extends NodeType<C, E> {
  const NodeTypeFinal(key, {strict = false}) : super(key, strict: strict);
}

class NodeTypeHistory<C, E> extends NodeType<C, E> {
  const NodeTypeHistory(key, {strict = false}) : super(key, strict: strict);
}

class NodeTypeParallel<C, E> extends NodeType<C, E> {
  final Map<String, StateNode<C, E>> states;

  const NodeTypeParallel(key, {this.states, strict = false})
      : super(key, strict: strict);

  @override
  bool get isLeafNode => false;

  @override
  StateTreeType<C, E> transitionFromTree(
          StateTreeNode<C, E> initialStateTreeNode,
          {StateTreeNode<C, E> oldTree,
          StateTreeNode<C, E> childBranch}) =>
      StateTreeParallel<C, E>(
          states.values.map<StateTreeNode<C, E>>((StateNode<C, E> stateNode) {
        if (childBranch != null && childBranch.matches(stateNode)) {
          return childBranch;
        } else if (oldTree.hasBranch(stateNode)) {
          return oldTree.getBranch(stateNode);
        }
        return stateNode.initialStateTreeNode;
      }).toList());

  @override
  StateTreeType<C, E> selectStateTree(
          {String key, StateTreeNode<C, E> childBranch}) =>
      StateTreeParallel<C, E>(
          states.values.map<StateTreeNode<C, E>>((StateNode<C, E> stateNode) {
        if (childBranch.matches(stateNode)) {
          return childBranch;
        }
        return stateNode.initialStateTreeNode;
      }).toList());
}

class NodeTypeCompound<C, E> extends NodeType<C, E> {
  final Map<String, StateNode<C, E>> states;

  const NodeTypeCompound(key, {this.states, strict})
      : super(key, strict: strict);

  @override
  bool get isLeafNode => false;

  @override
  StateTreeType<C, E> transitionFromTree(
      StateTreeNode<C, E> initialStateTreeNode,
      {StateTreeNode<C, E> oldTree,
      StateTreeNode<C, E> childBranch}) {
    if (childBranch != null) {
      return StateTreeCompound(childBranch);
    }
    return StateTreeCompound(initialStateTreeNode);
  }

  @override
  StateTreeType<C, E> selectStateTree(
      {String key, StateTreeNode<C, E> childBranch}) {
    if (childBranch != null) {
      return StateTreeCompound(childBranch);
    }
    if (key != null) {
      if (states.containsKey(key)) {
        return StateTreeCompound(states[key].initialStateTreeNode);
      }
      throw Exception("${key} is missing on substates!");
    }
    if (states.keys.length > 0) {
      return StateTreeCompound(states[states.keys.first].initialStateTreeNode);
    }

    assert(ifStrict || states.keys.length < 2,
        "You provided no valid initial state key for a compound node with several substates!");

    return StateTreeLeaf();
  }

  @override
  StateNode<C, E> selectTargetNode(String key) {
    if (states.containsKey(key)) {
      return states[key];
    }
    assert(ifStrict, "${key} is missing on substates!");

    return null;
  }
}

typedef LazyAccess<T> = T Function();

typedef LazyMapAccess<T> = T Function(String key);

class SideEffects<C, E> {
  final SideEffects<C, E> parent;

  final Map<String, Action<C, E>> actions;
  final Map<String, ActionExecute<C, E>> executions;
  final Map<String, ActionAssign<C, E>> assignments;
  final Map<String, Activity<C, E>> activities;
  final Map<String, Guard<C, E>> guards;

  final bool _ifStrict;

  const SideEffects(
      {this.parent,
      this.actions = const {},
      this.assignments = const {},
      this.activities = const {},
      this.executions = const {},
      this.guards = const {},
      strict = false})
      : this._ifStrict = !strict;

  List<Action<C, E>> getActions(dynamic action) {
    if (action is List) {
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
    if (actions.containsKey(action)) {
      return actions[action];
    } else if (executions.containsKey(action)) {
      return executions[action];
    } else if (assignments.containsKey(action)) {
      return assignments[action];
    } else if (parent != null) {
      return parent[action];
    }

    assert(_ifStrict, "Action ${action} missing in action map");
    return Action<C, E>(action);
  }

  Action<C, E> operator [](String action) => getAction(action);

  List<Activity<C, E>> getActivities(dynamic activity) {
    if (activity is List) {
      return activity
          .expand<Activity<C, E>>((single) => getActivities(single))
          .toList();
    } else if (activity is Activity<C, E>) {
      return [activity];
    } else if (activity == null) {
      return [];
    } else if (activity is String) {
      return [getActivity(activity)];
    }
    return [];
  }

  Activity<C, E> getActivity(String activity) {
    if (activities.containsKey(activity)) {
      return activities[activity];
    } else if (parent != null) {
      return parent.getActivity(activity);
    }

    assert(_ifStrict, "Activity ${activity} missing in activity map");
    return Activity<C, E>(activity);
  }

  Guard<C, E> getGuard(String guard) {
    if (guards.containsKey(guard)) {
      return guards[guard];
    } else if (parent != null) {
      return parent.getGuard(guard);
    }

    assert(_ifStrict, "Guard ${guard} missing in guard map ${guards}");
    return GuardMatches<C, E>();
  }
}

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

class StateNode<C, E> {
  final String id;
  final List<String> path;
  final String delimiter;

  final TreeAccess<C, E> tree;
  final SideEffects<C, E> sideEffects;

  final Map<String, List<Transition<C, E>>> transitions;
  final List<Action<C, E>> onEntry;
  final List<Action<C, E>> onExit;
  final List<Activity<C, E>> onActive;
  final StateTreeType<C, E> initialStateTree;

  final NodeType<C, E> type;

  final C context;

  final Map<String, dynamic> config;

  final bool strict;

  final Logger _log;

  const StateNode(
      {this.config,
      id,
      this.delimiter,
      this.path,
      this.type,
      this.tree,
      this.sideEffects,
      this.transitions = const {},
      this.onEntry = const [],
      this.onExit = const [],
      this.onActive = const [],
      this.initialStateTree = null,
      this.context = null,
      this.strict = false,
      log})
      : this._log = log,
        this.id = id,
        assert(!strict || config == null || id != "",
            "You provided no ID for the machine!");

  log(Level logLevel, dynamic message) =>
      _log != null ? _log.log(logLevel, message) : null;

  StateNode<C, E> get parent => tree.parent;
  StateNode<C, E> get root => tree.root;
  Action<C, E> operator [](String action) => sideEffects[action];

  String get key => type.key;

  State<C, E> get initialState {
    ActionCollector<C, E> collector =
        ActionCollector(this.initialStateTreeNode);
    return State<C, E>(this.initialStateTreeNode,
        actions: collector.onEntry,
        activities: {for (var a in collector.activities) a.type: true},
        context: context);
  }

  StateTreeNode<C, E> get initialStateTreeNode =>
      StateTreeNode<C, E>(this, initialStateTree, log: Logger("StateTreeNode"));

  StateTreeNode<C, E> transitionFromTree(StateTreeNode<C, E> oldTree,
      {StateTreeNode<C, E> childBranch}) {
    if (childBranch == null) {
      // Entry into target node
      if (oldTree.hasBranch(this)) {
        childBranch = oldTree.getBranch(this);
      }
    }
    StateTreeNode<C, E> thisAsChildBranch = StateTreeNode<C, E>(
        this,
        type.transitionFromTree(initialStateTreeNode,
            oldTree: oldTree, childBranch: childBranch),
        log: Logger("StateTreeNode"));
    return parent == null
        ? childBranch
        : parent.transitionFromTree(oldTree, childBranch: thisAsChildBranch);
  }

  StateNode<C, E> selectTargetNode(String key) {
    StateNode<C, E> target = type.selectTargetNode(key) ?? this;

    log(Level.FINE,
        () => "${toString()} selecting node ${key} as \"${target}\"");

    return target;
  }

  StateTreeNode<C, E> select(String key, {StateTreeNode<C, E> childBranch}) {
    log(
        Level.FINE,
        () =>
            "${toString()} selecting branch ${key} with child branch \"${childBranch}\"");

    StateTreeNode<C, E> thisAsChildBranch = StateTreeNode<C, E>(
        this, type.selectStateTree(key: key, childBranch: childBranch),
        log: Logger("StateTreeNode"));

    log(Level.FINE,
        () => "${toString()} selected child branch \n${thisAsChildBranch}");

    if (parent == null) {
      return thisAsChildBranch;
    }

    StateTreeNode<C, E> fullBranch =
        parent.select(type.key, childBranch: thisAsChildBranch);

    log(
        Level.FINE,
        () =>
            "${toString()} selected full branch \n${fullBranch}\nfrom parent ${parent.toString()}");

    return fullBranch;
  }

  State<C, E> transition(State<C, E> state, Event<E> event) {
    log(Level.FINE, () => "${toString()} transitioning on ${event.toString()}");

    return state.value.transition(state, event);
  }

  Transition<C, E> next(State<C, E> state, Event<E> event) {
    var matchingTransitions = getTransitionFor(event).skipWhile(
        (transition) => transition.doesNotMatch(state.context, event));
    if (!matchingTransitions.isEmpty) {
      return matchingTransitions.first;
    }
    return NoTransition<C, E>();
  }

  List<Transition<C, E>> getTransitionFor(Event<E> event) {
    if (!transitions.containsKey(event.type)) {
      return <Transition<C, E>>[];
    }
    return transitions[event.type];
  }

  @override
  String toString() => "${StateNode}(${id})";
}

//***********************************************
// SETUP
//***********************************************

class Setup<C, E> {
  bool _strict;

  bool get _ifStrict => !_strict;

  final Logger _log = Logger("Setup");

  StateNode<C, E> machine(Map<String, dynamic> config,
      {ContextFactory<C> contextFactory,
      Map<String, Action<C, E>> actions,
      Map<String, ActionExecute<C, E>> executions,
      Map<String, ActionAssign<C, E>> assignments,
      Map<String, Activity<C, E>> activities,
      Map<String, Guard<C, E>> guards}) {
    setStrict(config);

    StateNode<C, E> root;

    StateNode<C, E> getRoot() => root;

    SideEffects<C, E> rootSideEffects = SideEffects<C, E>(
        actions: actions,
        executions: executions,
        assignments: assignments,
        activities: activities,
        guards: guards,
        strict: _strict);

    TreeAccess<C, E> treeAccess = TreeAccess<C, E>(getRoot);

    root = configure(config,
        contextFactory: contextFactory,
        parentSideEffects: rootSideEffects,
        treeAccess: treeAccess);

    return root;
  }

  setStrict(Map<String, dynamic> config) {
    _strict = config.containsKey('strict') ? config['strict'] as bool : false;
  }

  StateNode<C, E> configure(Map<String, dynamic> config,
      {ContextFactory<C> contextFactory,
      String key,
      TreeAccess<C, E> treeAccess,
      LazyAccess<StateNode<C, E>> getRoot,
      SideEffects<C, E> parentSideEffects}) {
    StateNode<C, E> node;

    LazyAccess<StateNode<C, E>> getParent = () => node;

    TreeAccess<C, E> parentTreeAccess =
        treeAccess.clone(newGetParent: getParent);

    NodeType<C, E> type = configureNodeType(
      config,
      parentTreeAccess,
      key: key,
    );

    SideEffects<C, E> sideEffects =
        SideEffects<C, E>(parent: parentSideEffects, strict: _strict);

    List<String> path = parentTreeAccess.path + [type.key];

    String stateDelimiter = config['delimiter'] ??
        (parentTreeAccess.hasParent ? parentTreeAccess.parent.delimiter : '.');

    node = StateNode<C, E>(
        config: config,
        delimiter: stateDelimiter,
        path: path,
        id: (config['id'] ?? path.join(stateDelimiter) ?? "(machine)")
            as String,
        type: type,
        tree: treeAccess,
        transitions: config['on'] != null
            ? configureTransitions(config['on'], sideEffects, treeAccess)
            : const {},
        onEntry: sideEffects.getActions(config['onEntry']),
        onExit: sideEffects.getActions(config['onExit']),
        onActive: sideEffects.getActivities(config['activities']),
        initialStateTree: type.selectStateTree(key: config["initial"]),
        context: contextFactory != null && !config['context'].isEmpty
            ? contextFactory.fromMap(config['context'])
            : null,
        log: Logger("StateNode"));

    return node;
  }

  NodeType<C, E> configureNodeType(
      Map<String, dynamic> config, TreeAccess<C, E> treeAccess,
      {String key}) {
    String nodeKey =
        (config["key"] ?? key ?? config["id"] ?? "(machine)") as String;
    if (config.containsKey("type")) {
      switch (config["type"]) {
        case "final":
          return NodeTypeFinal(nodeKey, strict: _strict);
        case "history":
          return NodeTypeHistory(nodeKey, strict: _strict);
        case "atomic":
          return NodeTypeAtomic(nodeKey, strict: _strict);
        case "compound":
          return configureSubNodes(config, "compound", nodeKey, treeAccess);
        case "parallel":
          return configureSubNodes(config, "parallel", nodeKey, treeAccess);
        default:
          assert(_ifStrict, "Node type \"${config['type']}\" not supported!");
          return NodeTypeFinal(nodeKey, strict: _strict);
      }
    }

    if (config.containsKey('states')) {
      return configureSubNodes(config, "compound", nodeKey, treeAccess);
    }
    return NodeTypeAtomic(nodeKey, strict: _strict);
  }

  NodeType<C, E> configureSubNodes(Map<String, dynamic> config, String type,
      String nodeKey, TreeAccess<C, E> treeAccess) {
    assert(
        !_strict ||
            config.containsKey("states") ||
            (config["states"] is Map<String, dynamic> &&
                !config["states"].isEmpty()),
        "You provided no sub nodes for a machine of type \"${type}\"!");

    Map<String, StateNode<C, E>> substates = config.containsKey('states')
        ? config['states'].map<String, StateNode<C, E>>(
            (String key, dynamic state) => MapEntry<String, StateNode<C, E>>(
                key,
                configure(Map<String, dynamic>.from(state),
                    key: key, treeAccess: treeAccess)))
        : const {};

    if (type == "parallel") {
      return NodeTypeParallel(nodeKey, states: substates, strict: _strict);
    }
    return NodeTypeCompound(nodeKey, states: substates, strict: _strict);
  }

  Map<String, List<Transition<C, E>>> configureTransitions(dynamic transitions,
          SideEffects<C, E> sideEffects, TreeAccess<C, E> treeAccess) =>
      transitions.map<String, List<Transition<C, E>>>((String key,
              dynamic transition) =>
          MapEntry<String, List<Transition<C, E>>>(
              key,
              transition is List
                  ? transition
                      .map<Transition<C, E>>((t) =>
                          configureTransition(t, sideEffects, treeAccess))
                      .toList()
                  : [configureTransition(transition, sideEffects, treeAccess)]));

  Transition<C, E> configureTransition(dynamic transition,
          SideEffects<C, E> sideEffects, TreeAccess<C, E> treeAccess) =>
      Transition<C, E>(
          getTarget: _cache<StateNode<C, E>>(
              this.resolveTarget(transition, treeAccess)),
          actions: (transition is Map<String, dynamic>)
              ? sideEffects.getActions(transition['actions'])
              : [],
          condition: (transition is Map<String, dynamic>)
              ? sideEffects.getGuard(transition['cond'])
              : GuardMatches<C, E>());

  LazyAccess<StateNode<C, E>> resolveTarget(
          dynamic transition, TreeAccess<C, E> treeAccess) =>
      () {
        dynamic target = (transition is Map<String, dynamic>)
            ? transition['target']
            : transition;

        _log.log(
            Level.FINE,
            () =>
                "Resolving target by asking ${treeAccess.parent} to select target \"${target}\"");

        //TODO: Richer target definition (e.g. by node ID or multi-level)
        StateNode<C, E> targetNode = treeAccess.parent.selectTargetNode(target);

        _log.log(Level.FINE,
            () => "Resolved target \"${target}\" to \"${targetNode}\"");

        return targetNode;
      };

  LazyAccess<T> _cache<T>(LazyAccess<T> func) {
    T _cache;

    LazyAccess<T> cachedFunc = () {
      if (_cache == null) {
        _cache = func();
      }

      return _cache;
    };

    return cachedFunc;
  }
}

//***********************************************
// INTERPRETER
//***********************************************

enum InterpreterStatus { NotStarted, Running, Stopped }

typedef StateListener<C, E> = Function(State<C, E> state);

class Interpreter<C, E> {
  static const INIT_EVENT = Event('xstate.init');

  final StateNode<C, E> machine;
  InterpreterStatus _status;
  List<StateListener<C, E>> _listeners = [];
  State<C, E> _currentState;

  Interpreter(StateNode<C, E> this.machine)
      : _status = InterpreterStatus.NotStarted,
        _currentState = machine.initialState;

  void _executeStateActions(State<C, E> state, Event<E> event) {
    for (Action<C, E> action in state.actions) {
      if (action is ActionExecute<C, E>) {
        action.execute(state.context, event);
      }
    }
  }

  void send(Event<E> event) {
    if (_status != InterpreterStatus.Running) {
      return;
    }
    _currentState = machine.transition(_currentState, event);
    _executeStateActions(_currentState, event);
    _listeners.forEach((listener) => listener(_currentState));
  }

  Map<String, Function()> subscribe(StateListener<C, E> listener) {
    _listeners.add(listener);
    listener(_currentState);

    return {"unsubscribe": () => _listeners.remove(listener)};
  }

  Interpreter<C, E> start() {
    _status = InterpreterStatus.Running;
    _executeStateActions(_currentState, INIT_EVENT);
    return this;
  }

  Interpreter<C, E> stop() {
    _status = InterpreterStatus.Stopped;
    _listeners.clear();
    return this;
  }

  InterpreterStatus get status => _status;
}
