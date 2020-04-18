import 'interfaces.dart';

class ServiceBase<C, E> extends Service<C, E> {
  final Map<String, List<Transition<C, E>>> onDone;
  final Map<String, List<Transition<C, E>>> onError;

  const ServiceBase(id, {this.onDone, this.onError}) : super(id);

  @override
  Map<String, List<Transition<C, E>>> get transitions =>
      {...onDone, ...onError};
}

class ServiceFuture<F, C, E> extends ServiceBase<C, E> {
  final Future<F> future;

  const ServiceFuture(id, this.future, {onDone, onError})
      : super(id, onDone: onDone, onError: onError);

  @override
  String toString() {
    return "${ServiceFuture}(${id})";
  }
}

class ServiceMachine<SC, SE, C, E> extends ServiceBase<C, E> {
  final StateNode<SC, SE> machine;

  const ServiceMachine(id, this.machine, {onDone, onError})
      : super(id, onDone: onDone, onError: onError);

  @override
  String toString() {
    return "${ServiceMachine}(${id})";
  }
}
