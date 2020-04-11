import 'actions.dart';
import 'activities.dart';
import 'context.dart';
import 'guards.dart';
import 'log.dart';
import 'node.dart';
import 'sideEffects.dart';
import 'transitions.dart';

class Setup<C, E> {
  bool _strict;

  bool get _ifStrict => !_strict;

  Log log = const Log();

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
      SideEffects<C, E> parentSideEffects,
      LazyAccess<StateNode<C, E>> getRoot}) {
    checkValidKeys(config, validStateKeys);

    StateNode<C, E> node;

    LazyAccess<StateNode<C, E>> getParent = () => node;

    TreeAccess<C, E> parentTreeAccess =
        treeAccess.clone(newGetParent: getParent);

    SideEffects<C, E> sideEffects =
        SideEffects<C, E>(parent: parentSideEffects, strict: _strict);

    NodeType<C, E> type = configureNodeType(
      config,
      parentTreeAccess,
      parentSideEffects,
      key: key,
    );

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
        onEntry: config.containsKey('onEntry')
            ? sideEffects.getActions(config['onEntry'])
            : [],
        onExit: config.containsKey('onExit')
            ? sideEffects.getActions(config['onExit'])
            : [],
        onActive: config.containsKey('activities')
            ? sideEffects.getActivities(config['activities'])
            : [],
        initialStateTree: type.selectStateTree(key: config["initial"]),
        sideEffects: sideEffects,
        context: contextFactory != null && !config['context'].isEmpty
            ? contextFactory.fromMap(config['context'])
            : null);

    return node;
  }

  NodeType<C, E> configureNodeType(Map<String, dynamic> config,
      TreeAccess<C, E> treeAccess, SideEffects<C, E> parentSideEffects,
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
          return configureSubNodes(
              config, "compound", nodeKey, treeAccess, parentSideEffects);
        case "parallel":
          return configureSubNodes(
              config, "parallel", nodeKey, treeAccess, parentSideEffects);
        default:
          assert(_ifStrict, "Node type \"${config['type']}\" not supported!");
          return NodeTypeFinal(nodeKey, strict: _strict);
      }
    }

    if (config.containsKey('states')) {
      return configureSubNodes(
          config, "compound", nodeKey, treeAccess, parentSideEffects);
    }
    return NodeTypeAtomic(nodeKey, strict: _strict);
  }

  NodeType<C, E> configureSubNodes(
      Map<String, dynamic> config,
      String type,
      String nodeKey,
      TreeAccess<C, E> treeAccess,
      SideEffects<C, E> parentSideEffects) {
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
                    key: key,
                    treeAccess: treeAccess,
                    parentSideEffects: parentSideEffects)))
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

  dynamic readTarget(dynamic transition) =>
      (transition is Map<String, dynamic>) ? transition['target'] : transition;

  Transition<C, E> configureTransition(dynamic transition,
      SideEffects<C, E> sideEffects, TreeAccess<C, E> treeAccess) {
    dynamic target = readTarget(transition);
    return Transition<C, E>(
        getTarget: target == null
            ? target
            : _cache<StateNode<C, E>>(this.resolveTarget(target, treeAccess)),
        actions: (transition is Map<String, dynamic> &&
                transition['actions'] != null)
            ? sideEffects.getActions(transition['actions'])
            : [],
        condition:
            (transition is Map<String, dynamic> && transition['cond'] != null)
                ? sideEffects.getGuard(transition['cond'])
                : GuardMatches<C, E>());
  }

  LazyAccess<StateNode<C, E>> resolveTarget(
          dynamic target, TreeAccess<C, E> treeAccess) =>
      () {
        log.fine(
            this,
            () =>
                "Resolving target by asking ${treeAccess.parent} to select target \"${target}\"");

        //TODO: Richer target definition (e.g. by node ID or multi-level)
        StateNode<C, E> targetNode = treeAccess.parent.selectTargetNode(target);

        log.fine(
            this, () => "Resolved target \"${target}\" to \"${targetNode}\"");

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

  static List<String> validStateKeys = [
    'id',
    'initial',
    'context',
    'states',
    'onEntry',
    'onExit',
    'on',
    'delimiter',
    'activities',
    'delimiter',
    'strict'
  ];

  void checkValidKeys(Map<String, dynamic> config, List<String> validKeys) {
    assert(
        _ifStrict || config.keys.every((String key) => validKeys.contains(key)),
        "Node type \"${config['type']}\" not supported!");
  }
}
