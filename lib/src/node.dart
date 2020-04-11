import 'actions.dart';
import 'activities.dart';
import 'event.dart';
import 'log.dart';
import 'sideEffects.dart';
import 'state.dart';
import 'transitions.dart';
import 'tree.dart';

abstract class NodeType<C, E> {
  final String key;
  final bool _strict;

  final Log log;

  const NodeType(this.key, {strict = false, this.log = const Log()})
      : this._strict = strict;

  bool get isLeafNode => true;
  bool get ifStrict => !_strict;

  StateTreeType<C, E> transitionFromTree(
      StateTreeNode<C, E> initialStateTreeNode,
      {StateTreeNode<C, E> oldTree,
      StateTreeNode<C, E> childBranch}) {
    log.fine(this, () => "Leaf does not transition");

    return StateTreeLeaf<C, E>();
  }

  StateTreeType<C, E> selectStateTree(
          {String key, StateTreeNode<C, E> childBranch}) =>
      StateTreeLeaf<C, E>();

  StateNode<C, E> selectTargetNode(String key) => null;

  String toString() => "${NodeType}(${key})";
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
      StateTreeType<C, E> childTree = StateTreeCompound(childBranch);
      log.fine(this, () => "Created child tree ${childTree}");
      return childTree;
    }
    StateTreeType<C, E> initialTree = StateTreeCompound(initialStateTreeNode);
    log.fine(this, () => "Created initial tree ${initialTree}");
    return initialTree;
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

  final Log log;

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
      this.log = const Log()})
      : this.id = id,
        assert(!strict || config == null || id != "",
            "You provided no ID for the machine!");

  StateNode<C, E> get parent => tree.parent;
  StateNode<C, E> get root => tree.root;
  Action<C, E> operator [](String action) => sideEffects[action];

  String get key => type.key;

  State<C, E> get initialState {
    log.finest(this, () => "Determine initial state");
    StateTreeNode<C, E> initialTree = this.initialStateTreeNode;
    ActionCollector<C, E> collector = ActionCollector(initialTree);
    log.finer(this, () => "Collected initial actions ${collector.onEntry}");
    return State<C, E>(initialTree,
        actions: collector.onEntry,
        activities: {for (var a in collector.activities) a.type: true},
        context: context);
  }

  StateTreeNode<C, E> get initialStateTreeNode {
    StateTreeNode<C, E> initial = StateTreeNode<C, E>(this, initialStateTree);
    log.finest(this, () => "Initial tree is \n${initial}\n");
    return initial;
  }

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
      thisAsChildBranch = StateTreeNode<C, E>(
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

    StateTreeNode<C, E> thisAsChildBranch = StateTreeNode<C, E>(
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

  State<C, E> transitionUntyped(dynamic state, dynamic event) {
    State<C, E> typedState;
    Event<E> typedEvent;

    if (state is String) {
      typedState = State<C, E>(this.select(state));
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

  State<C, E> transition(State<C, E> state, Event<E> event) {
    log.fine(this, () => "Transitioning on ${event}");

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
