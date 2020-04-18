import 'actions.dart';
import 'activities.dart';
import 'guards.dart';
import 'interfaces.dart';
import 'log.dart';
import 'node.dart';
import 'nodeType.dart';
import 'state.dart';
import 'services.dart';
import 'tree.dart';
import 'transitions.dart';
import 'sideEffects.dart';

class Setup<C, E> {
  StandardActionFactory<C, E> actionFactory = StandardActionFactory<C, E>();
  StandardActivityFactory<C, E> activityFactory =
      StandardActivityFactory<C, E>();
  StandardGuardFactory<C, E> guardFactory = StandardGuardFactory<C, E>();
  StandardStateFactory<C, E> stateFactory;
  StandardStateTreeFactory<C, E> treeFactory;

  Setup() {
    this.stateFactory = StandardStateFactory<C, E>();
    this.treeFactory = StandardStateTreeFactory<C, E>(stateFactory);
  }

  Log log = const Log();

  StateNode<C, E> machine(Map<String, dynamic> config,
      {ContextFactory<C> contextFactory,
      C initialContext,
      Map<String, Action<C, E>> actions,
      Map<String, ActionExecute<C, E>> executions,
      Map<String, ActionAssign<C, E>> assignments,
      List<Activity<C, E>> activities,
      List<Service<C, E>> services,
      Map<String, Guard<C, E>> guards}) {
    StandardValidation<C, E> validation = StandardValidation<C, E>(config);

    StateNode<C, E> root;

    StateNode<C, E> getRoot() => root;

    validation.checkActivities(activities);
    validation.checkServices(services);

    SideEffects<C, E> rootSideEffects = StandardSideEffects<C, E>(
        actionFactory, activityFactory, guardFactory,
        validation: validation,
        actions: actions,
        executions: executions,
        assignments: assignments,
        activities: activities != null
            ? Map<String, Activity<C, E>>.fromIterable(activities,
                key: (a) => a.id, value: (a) => a)
            : const {},
        services: services != null
            ? Map<String, Service<C, E>>.fromIterable(services,
                key: (s) => s.id, value: (s) => s)
            : const {},
        guards: guards);

    TreeAccess<C, E> treeAccess = TreeAccess<C, E>(getRoot);

    C parsedInitialContext = initialContext != null
        ? initialContext
        : contextFactory != null && !config['context'].isEmpty
            ? contextFactory.fromMap(config['context'])
            : null;

    root = configure(config, validation,
        initialContext: parsedInitialContext,
        contextFactory: contextFactory,
        parentSideEffects: rootSideEffects,
        treeAccess: treeAccess);

    validation.report(initialContext: parsedInitialContext);

    return root;
  }

  StateNode<C, E> configure(
      Map<String, dynamic> config, StandardValidation<C, E> validation,
      {ContextFactory<C> contextFactory,
      C initialContext,
      String key,
      TreeAccess<C, E> treeAccess,
      SideEffects<C, E> parentSideEffects,
      LazyAccess<StateNode<C, E>> getRoot}) {
    validation.checkValidKeys(config);

    StateNode<C, E> node;

    LazyAccess<StateNode<C, E>> getParent = () => node;

    TreeAccess<C, E> parentTreeAccess =
        treeAccess.clone(newGetParent: getParent);

    SideEffects<C, E> sideEffects = StandardSideEffects<C, E>(
        actionFactory, activityFactory, guardFactory,
        parent: parentSideEffects);

    NodeType<C, E> type = configureNodeType(
      config,
      validation,
      parentTreeAccess,
      parentSideEffects,
      key: key,
    );

    List<String> path = parentTreeAccess.path + [type.key];

    if (type.isFinal && !(treeAccess.parent.type is NodeTypeCompound<C, E>)) {
      validation.reportError(
          "Final node ${path} can only be child of a compound node!",
          data: {"type": type, "parent": treeAccess.parent});
    }

    String stateDelimiter = config['delimiter'] ??
        (parentTreeAccess.hasParent ? parentTreeAccess.parent.delimiter : '.');

    List<Service<C, E>> services = config.containsKey('invoke')
        ? configureServices(config['invoke'], sideEffects, treeAccess)
        : List<Service<C, E>>();

    Map<String, List<Transition<C, E>>> serviceTransitions = services.fold(
        Map<String, List<Transition<C, E>>>(),
        (transitionMap, service) => {...transitionMap, ...service.transitions});

    Map<String, List<Transition<C, E>>> configTransitions = config['on'] != null
        ? configureTransitions(config['on'], sideEffects, treeAccess)
        : Map<String, List<Transition<C, E>>>();

    List<Activity<C, E>> activities = config.containsKey('activities')
        ? sideEffects.getActivities(config['activities'])
        : List<Activity<C, E>>();

    node = StandardStateNode<C, E>(treeFactory,
        config: config,
        delimiter: stateDelimiter,
        path: path,
        id: (config['id'] ?? path.join(stateDelimiter) ?? "(machine)")
            as String,
        type: type,
        tree: treeAccess,
        transitions: {...configTransitions, ...serviceTransitions},
        onEntry: config.containsKey('onEntry')
            ? sideEffects.getActions(config['onEntry'])
            : List<Action<C, E>>(),
        onExit: config.containsKey('onExit')
            ? sideEffects.getActions(config['onExit'])
            : List<Action<C, E>>(),
        onActive: activities,
        onActiveStart: activities
            .map<Action<C, E>>(
                (activity) => actionFactory.createStartActivity(activity))
            .toList(),
        onActiveStop: activities
            .map<Action<C, E>>(
                (activity) => actionFactory.createStopActivity(activity))
            .toList(),
        services: services,
        onServiceStart: services
            .map<Action<C, E>>(
                (service) => actionFactory.createStartService(service))
            .toList(),
        onServiceStop: services
            .map<Action<C, E>>(
                (service) => actionFactory.createStopService(service))
            .toList(),
        initialStateTree: type.selectStateTree(key: config["initial"]),
        sideEffects: sideEffects,
        context: initialContext);

    return node;
  }

  NodeType<C, E> configureNodeType(
      Map<String, dynamic> config,
      StandardValidation<C, E> validation,
      TreeAccess<C, E> treeAccess,
      SideEffects<C, E> parentSideEffects,
      {String key}) {
    String nodeKey =
        (config["key"] ?? key ?? config["id"] ?? "(machine)") as String;
    if (config.containsKey("type")) {
      switch (config["type"]) {
        case "final":
          return NodeTypeFinal(nodeKey, treeFactory);
        case "history":
          return NodeTypeHistory(nodeKey, treeFactory);
        case "atomic":
          return NodeTypeAtomic(nodeKey, treeFactory);
        case "compound":
          return configureSubNodes(config, validation, "compound", nodeKey,
              treeAccess, parentSideEffects);
        case "parallel":
          return configureSubNodes(config, validation, "parallel", nodeKey,
              treeAccess, parentSideEffects);
        default:
          validation.reportError(
              "Node type \"${config['type']}\" not supported!",
              data: {"type": config['type']});
          return NodeTypeAtomic(nodeKey, treeFactory);
      }
    }

    if (config.containsKey('states')) {
      return configureSubNodes(
        config,
        validation,
        "compound",
        nodeKey,
        treeAccess,
        parentSideEffects,
      );
    }
    return NodeTypeAtomic(nodeKey, treeFactory);
  }

  NodeType<C, E> configureSubNodes(
      Map<String, dynamic> config,
      StandardValidation<C, E> validation,
      String type,
      String nodeKey,
      TreeAccess<C, E> treeAccess,
      SideEffects<C, E> parentSideEffects) {
    if (!config.containsKey("states") ||
        (config["states"] is Map<String, dynamic> &&
            config["states"].isEmpty)) {
      validation.reportError(
          "You provided no sub nodes for a machine of type \"${type}\"!");
    }

    Map<String, StateNode<C, E>> substates = config.containsKey('states')
        ? config['states'].map<String, StateNode<C, E>>(
            (String key, dynamic state) => MapEntry<String, StateNode<C, E>>(
                key,
                configure(Map<String, dynamic>.from(state), validation,
                    key: key,
                    treeAccess: treeAccess,
                    parentSideEffects: parentSideEffects)))
        : const {};

    if (type == "parallel") {
      return NodeTypeParallel(nodeKey, treeFactory, states: substates);
    }
    return NodeTypeCompound(nodeKey, treeFactory, states: substates);
  }

  List<Service<C, E>> configureServices(dynamic service,
      SideEffects<C, E> sideEffects, TreeAccess<C, E> treeAccess) {
    if (service is List) {
      List<Service<C, E>> services = service
          .expand<Service<C, E>>(
              (single) => configureServices(single, sideEffects, treeAccess))
          .toList();

      log.fine(
          this, () => "Extracted ${services.length} services from List config");

      log.fine(this, () => "Extracted ${services}");

      return services;
    } else if (service is Map<String, dynamic> && service.containsKey('src')) {
      Map<String, List<Transition<C, E>>> onDone = service['onDone'] != null
          ? configureTransitions(service['onDone'], sideEffects, treeAccess)
          : <String, List<Transition<C, E>>>{};
      Map<String, List<Transition<C, E>>> onError = service['onError'] != null
          ? configureTransitions(service['onError'], sideEffects, treeAccess)
          : <String, List<Transition<C, E>>>{};

      if (service['src'] is String) {
        return sideEffects.getServices(service['src']);
      } else if (service['src'] is Future) {
        return [
          ServiceFuture<dynamic, C, E>(service['id'], service['src'],
              onDone: onDone, onError: onError)
        ];
      } else if (service['src'] is StateNode<C, E>) {
        return [
          ServiceMachine<C, E, C, E>(service['id'], service['src'],
              onDone: onDone, onError: onError)
        ];
      } else if (service['src'] is Map<String, dynamic>) {
        return [
          ServiceMachine<C, E, C, E>(service['id'], machine(service['src']),
              onDone: onDone, onError: onError)
        ];
      }
    }
    return sideEffects.getServices(service);
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
    return StandardTransition<C, E>(
        getTarget: target == null
            ? target
            : _cache<StateNode<C, E>>(this.resolveTarget(target, treeAccess)),
        actions: (transition is Map<String, dynamic> &&
                transition['actions'] != null)
            ? sideEffects.getActions(transition['actions'])
            : List<Action<C, E>>(),
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
}

class StandardValidation<C, E> extends Validation {
  List<String> _errors = [];
  bool _requiresContext = false;

  bool _strict;

  bool get _ifStrict => !_strict;

  static List<String> validStateKeys = [
    'id',
    'key',
    'initial',
    'type',
    'context',
    'states',
    'onEntry',
    'onExit',
    'on',
    'delimiter',
    'activities',
    'invoke',
    'delimiter',
    'strict'
  ];

  StandardValidation(Map<String, dynamic> config) {
    setStrict(config);
  }

  setStrict(Map<String, dynamic> config) {
    _strict = config.containsKey('strict') ? config['strict'] as bool : true;
  }

  void checkValidKeys(Map<String, dynamic> config) {
    if (!config.keys.every((String key) => validStateKeys.contains(key))) {
      List<String> invalidKeys = config.keys
          .where((String key) => !validStateKeys.contains(key))
          .toList();
      assert(_ifStrict, "Config keys ${invalidKeys.join(', ')} not supported!");
    }
  }

  void _assertUniqueId(List<HasId> activitiesOrServices) {
    List<String> ids = [];
    activitiesOrServices.forEach((activityOrService) {
      assert(_ifStrict || !ids.contains(activityOrService.id),
          "Duplicate ID ${activityOrService.id} in ");
      ids.add(activityOrService.id);
    });
    return null;
  }

  void checkActivities(List<Activity<C, E>> activities) {
    if (activities != null) {
      _assertUniqueId(activities);
    }
  }

  void checkServices(List<Service<C, E>> services) {
    if (services != null) {
      _assertUniqueId(services);
    }
  }

  @override
  void reportError(String message, {Map<String, dynamic> data}) {
    _errors.add(message);
  }

  @override
  void requireContext() {
    _requiresContext = true;
  }

  void report({C initialContext}) {
    String report;

    if (_requiresContext && initialContext == null) {
      _errors.add(
          'Machine has assignement actions but the intial context is null!');
    }

    if (_errors.length > 0) {
      report = _errors.join("\n");
      assert(false,
          "Machine setup failed because of validation errors:\n${report}");
    }
  }
}
