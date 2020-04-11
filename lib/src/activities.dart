import 'package:equatable/equatable.dart';

typedef ActivityDisposal = Function();
typedef ActivityImplementation<C, E> = ActivityDisposal Function(
    C context, Activity<C, E>);

class Activity<C, E> extends Equatable {
  final String id;
  final String type;
  final ActivityImplementation<C, E> implementation;

  const Activity(this.id, this.implementation, {type}) : this.type = type ?? id;

  @override
  List<Object> get props => [type, id];

  @override
  String toString() {
    return "${Activity}(${id}) type:\"${type}\"";
  }
}
