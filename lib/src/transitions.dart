import 'interfaces.dart';
import 'log.dart';

class StandardTransition<C, E> extends Transition<C, E> {
  final Guard<C, E> condition;

  final Log log;

  const StandardTransition(
      {getTarget, actions, this.condition, this.log = const Log()})
      : super(getTarget: getTarget, actions: actions);

  @override
  bool doesNotMatch(C context, Event<E> event) {
    return condition != null && !condition.matches(context, event);
  }
}
