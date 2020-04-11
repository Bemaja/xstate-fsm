import 'event.dart';

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
