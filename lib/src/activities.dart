import 'interfaces.dart';

class StandardActivity<C, E> extends Activity<C, E> {
  final ActivityImplementation<C, E> implementation;

  const StandardActivity(id, this.implementation, {type})
      : super(id, type: type);

  @override
  String toString() {
    return "${StandardActivity}(${id}) type:\"${type}\"";
  }
}

class StandardActivityFactory<C, E> extends ActivityFactory<C, E> {
  Activity<C, E> createEmptyActivity(String type) => StandardActivity<C, E>(
      type, (C context, Activity<C, E> activity) => () => {});
}
