import 'interfaces.dart';

class GuardConditional<C, E> extends Guard<C, E> {
  final GuardCondition<C, E> condition;

  const GuardConditional(GuardCondition<C, E> this.condition, {String type})
      : super(type: type);

  @override
  matches(C context, Event<E> event) => condition(context, event);
}

class GuardMatches<C, E> extends Guard<C, E> {
  const GuardMatches() : super(type: 'xstate.guard.matches');

  @override
  matches(C context, Event<E> event) => true;
}

class StandardGuardFactory<C, E> extends GuardFactory<C, E> {
  Guard<C, E> createMatchingGuard() => GuardMatches<C, E>();

  Guard<C, E> createGuard(GuardCondition<C, E> condition, {String type}) =>
      GuardConditional(condition, type: type);
}
