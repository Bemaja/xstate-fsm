import 'package:equatable/equatable.dart';

/*****************************
 *
 *   EVENT
 *
 *****************************/

enum EventType { platform, internal, external }

abstract class InternalEvent {
  const InternalEvent();
}

abstract class PlatformEvent {
  const PlatformEvent();
}

abstract class EventData {
  final EventType type;

  const EventData(this.type);
}

class ExternalEventData<E> extends EventData {
  final E externalEvent;

  const ExternalEventData(this.externalEvent) : super(EventType.external);
}

class InternalEventData extends EventData {
  final InternalEvent internalEvent;

  const InternalEventData(this.internalEvent) : super(EventType.internal);
}

class PlatformEventData extends EventData {
  final PlatformEvent platformEvent;

  const PlatformEventData(this.platformEvent) : super(EventType.platform);
}

class Event<E> {
  final String name;
  final EventData data;

  const Event(this.name, {ExternalEventData<E> this.data});

  const Event.internal(this.name, InternalEventData this.data);

  const Event.platform(this.name, PlatformEventData this.data);

  EventType get type => data == null ? EventType.external : data.type;

  E get externalEvent {
    EventData _data = data;
    if (_data is ExternalEventData<E>) {
      return _data.externalEvent;
    }
    return null;
  }

  @override
  String toString() => "${Event}(${type}:${name})";
}

class DoneEvent extends InternalEvent {
  final dynamic data;

  const DoneEvent({this.data});

  @override
  String toString() => "${DoneEvent}";
}

/*****************************
 *
 *   ACTION
 *
 *****************************/

typedef ActionExecution<C, E> = Function(C context, Event<E> event);
typedef ActionAssignment<C, E> = C Function(C context, Event<E> event);

abstract class Action extends Equatable {
  final String type;

  const Action(String this.type);

  @override
  List<Object> get props => [type];

  @override
  String toString() {
    return "${Action} of \"${type}\"";
  }
}

abstract class ActionExecute<C, E> extends Action {
  final ActionExecution<C, E> exec;

  const ActionExecute(type, ActionExecution<C, E> this.exec) : super(type);

  @override
  List<Object> get props => [type, exec];

  execute(C context, Event<E> event);
}

abstract class ActionAssign<C, E> extends Action {
  final ActionAssignment<C, E> assignment;

  const ActionAssign(this.assignment) : super('xstate.assign');

  @override
  List<Object> get props => [type, assignment];

  C assign(C context, Event<E> event);
}

abstract class ActionSend<E> extends Action {
  final Event<E> event;
  final String to;
  final String _id;
  final num delay;

  const ActionSend(this.event, this.to, {this.delay, id})
      : this._id = id,
        super('xstate.send');

  String get id => _id ?? event.type;

  @override
  List<Object> get props => [type, _id, to, event];
}

abstract class ActionRaise<C, E> extends Action {
  final String event;

  const ActionRaise(this.event) : super('xstate.raise');

  @override
  List<Object> get props => [type, event];
}

abstract class ActionStartActivity<C, E> extends Action {
  final Activity<C, E> activity;

  const ActionStartActivity(this.activity) : super('xstate.start');

  @override
  List<Object> get props => [type, activity];
}

abstract class ActionStopActivity<C, E> extends Action {
  final Activity<C, E> activity;

  const ActionStopActivity(this.activity) : super('xstate.stop');

  @override
  List<Object> get props => [type, activity];
}

abstract class ActionStartService<C, E> extends Action {
  final Service<C, E> service;

  const ActionStartService(this.service) : super('xstate.start');

  @override
  List<Object> get props => [type, service];
}

abstract class ActionStopService<C, E> extends Action {
  final Service<C, E> service;

  const ActionStopService(this.service) : super('xstate.stop');

  @override
  List<Object> get props => [type, service];
}

abstract class ActionFactory<C, E> {
  Action createSimpleAction(String type);
  Action createAssignmentAction(ActionAssignment<C, E> action);
  Action createExecutionAction(String type, ActionExecution<C, E> action);
  Action createStartActivity(Activity<C, E> activity);
  Action createStopActivity(Activity<C, E> activity);
  Action createStartService(Service<C, E> service);
  Action createStopService(Service<C, E> service);
  Action createSendAction(Event<E> event, String to, {num delay, String id});
  Action createDoneAction(String id, dynamic data);
}

/*****************************
 *
 *   ACTIVITY
 *
 *****************************/

typedef ActivityDisposal = Function();
typedef ActivityImplementation<C, E> = ActivityDisposal Function(
    C context, Activity<C, E>);

abstract class Activity<C, E> extends HasId {
  final String type;

  const Activity(id, {type})
      : this.type = type ?? id,
        super(id);

  @override
  List<Object> get props => [type, id];
}

abstract class ActivityFactory<C, E> {
  Activity<C, E> createEmptyActivity(String type);
}

/*****************************
 *
 *   SERVICES
 *
 *****************************/

abstract class Service<C, E> extends HasId {
  const Service(id) : super(id);

  Map<String, List<Transition<C, E>>> get transitions;
}

/*****************************
 *
 *   TRANSITION
 *
 *****************************/

abstract class Transition<C, E> {
  final LazyAccess<StateNode<C, E>> getTarget;
  final List<Action> actions;

  const Transition({this.getTarget, this.actions});

  bool doesNotMatch(C context, Event<E> event);
}

class NoTransition<C, E> extends Transition<C, E> {
  bool doesNotMatch(C context, Event<E> event) => false;
}

typedef GuardCondition<C, E> = bool Function(C context, Event<E> event);

abstract class Guard<C, E> {
  final String type;

  const Guard({String this.type = 'xstate.guard'});

  matches(C context, Event<E> event);
}

abstract class GuardFactory<C, E> {
  Guard<C, E> createMatchingGuard();
  Guard<C, E> createGuard(GuardCondition<C, E> condition, {String type});
}

/*****************************
 *
 *   STATE
 *
 *****************************/

abstract class State<C, E> {
  final StateTreeNode<C, E> value;
  final List<Action> actions;
  final C context;
  final bool changed;
  final Map<String, bool> activities;
  final List<dynamic> children;

  const State(this.value,
      {this.context,
      this.actions = const [],
      this.activities = const {},
      this.children = const [],
      this.changed});

  bool matches(String stateValue);
}

abstract class StateFactory<C, E> {
  State<C, E> createFromStateTreeNode(StateTreeNode<C, E> treeNode);
  State<C, E> createState(
      StateTreeNode<C, E> tree, List<Action> actions, C context,
      {Map<String, bool> activities = const {},
      List<Service<C, E>> children,
      bool changed = false});
}

/*****************************
 *
 *   CONTEXT
 *
 *****************************/

abstract class ContextFactory<C> {
  C fromMap(Map<String, dynamic> map);

  C copy(C original);
}

/*****************************
 *
 *   STATE TREE
 *
 *****************************/

typedef StateTreeWalk<T, C, E> = List<T> Function(StateTreeNode<C, E>);

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
  bool get isFinal;
  bool get hasTransientTransition;

  dynamic getDoneData(C context);
}

abstract class StateTreeLeaf<C, E> extends StateTreeType<C, E> {
  const StateTreeLeaf();
}

abstract class StateTreeParallel<C, E> extends StateTreeType<C, E> {
  const StateTreeParallel();
}

abstract class StateTreeCompound<C, E> extends StateTreeType<C, E> {
  const StateTreeCompound();
}

abstract class StateTreeNode<C, E> {
  final StateNode<C, E> node;
  final StateTreeType<C, E> type;

  const StateTreeNode(this.node, this.type);

  List<Action> collectPotentialDoneEvents(C context);

  dynamic toStateValue();

  Transition<C, E> resolveTransition(State<C, E> state, Event<E> event);

  List<String> toAscii({num level = 0});

  bool get isLeaf;

  bool get hasTransientTransition;

  bool matches(StateNode<C, E> matchingNode);

  bool hasBranch(StateNode<C, E> matchingNode);

  StateTreeNode<C, E> getBranch(StateNode<C, E> matchingNode);

  List<T> walkStateTree<T>(StateTreeWalk<T, C, E> walker);

  State<C, E> transition(State<C, E> state, Event<E> event);

  State<C, E> state({C context});
}

abstract class StateTreeFactory<C, E> {
  const StateTreeFactory();

  StateTreeNode<C, E> createTreeNode(
      StateNode<C, E> node, StateTreeType<C, E> type);
  StateTreeType<C, E> createTreeNodeType({List<StateTreeNode<C, E>> children});
}

/*****************************
 *
 *   MACHINE
 *
 *****************************/

abstract class NodeType<C, E> {
  final String key;

  const NodeType(this.key);

  bool get isLeafNode;
  bool get isFinal;

  StateTreeType<C, E> transitionFromTree(
      StateTreeNode<C, E> initialStateTreeNode,
      {StateTreeNode<C, E> oldTree,
      StateTreeNode<C, E> childBranch});

  StateTreeType<C, E> selectStateTree(
      {String key, StateTreeNode<C, E> childBranch});

  StateNode<C, E> selectTargetNode(String key);
}

abstract class StateNode<C, E> {
  final String id;
  final List<String> path;
  final String delimiter;

  final Map<String, dynamic> config;

  final Map<String, List<Transition<C, E>>> transitions;
  final List<Action> onEntry;
  final List<Action> onExit;
  final List<Activity<C, E>> onActive;
  final List<Action> onActiveStart;
  final List<Action> onActiveStop;
  final List<Service<C, E>> services;
  final List<Action> onServiceStart;
  final List<Action> onServiceStop;
  final dynamic data;
  final StateTreeType<C, E> initialStateTree;

  final NodeType<C, E> type;

  final C context;

  const StateNode(
      {this.id,
      this.config,
      this.delimiter,
      this.path,
      this.type,
      this.transitions = const {},
      this.onEntry = const [],
      this.onExit = const [],
      this.onActive = const [],
      this.onActiveStart = const [],
      this.onActiveStop = const [],
      this.services = const [],
      this.onServiceStart = const [],
      this.onServiceStop = const [],
      this.data,
      this.initialStateTree = null,
      this.context = null});

  String get key;

  bool get isFinal;

  bool get hasTransientTransition;

  Action operator [](String action);

  StateTreeNode<C, E> get initialStateTreeNode;

  State<C, E> transitionUntyped(dynamic state, dynamic event);

  State<C, E> transition(State<C, E> state, Event<E> event);

  StateTreeNode<C, E> transitionFromTree(StateTreeNode<C, E> oldTree,
      {StateTreeNode<C, E> childBranch});

  StateTreeNode<C, E> select(String key, {StateTreeNode<C, E> childBranch});

  Transition<C, E> next(State<C, E> state, Event<E> event);

  StateNode<C, E> selectTargetNode(String key);

  State<C, E> get initialState;

  Action raiseDone(dynamic data);
}

abstract class SideEffects<C, E> {
  const SideEffects();

  /* Node actions */
  Action operator [](String action);
  Action createDone(String id, dynamic data);

  /* Parent actions */
  Guard<C, E> getGuard(dynamic guard);
  Activity<C, E> getActivity(String activity);
  Service<C, E> getService(String service);

  void reportError(String message, {Map<String, dynamic> data});
  void requireContext();

  /* Setup actions */
  List<Action> getActions(dynamic action);
  List<Activity<C, E>> getActivities(dynamic activity);
  List<Service<C, E>> getServices(dynamic service);
}
/*****************************
 *
 *   SETUP
 *
 *****************************/

abstract class Validation {
  void reportError(String message, {Map<String, dynamic> data});

  void requireContext();
}

/*****************************
 *
 *   UTILS
 *
 *****************************/

typedef LazyAccess<T> = T Function();

typedef LazyMapAccess<T> = T Function(String key);

abstract class DataMapper<C> {
  dynamic call(C context);
}

abstract class HasId extends Equatable {
  final String id;

  const HasId(this.id);

  @override
  List<Object> get props => [id];
}
