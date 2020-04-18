import 'interfaces.dart';

typedef StateMatcher = bool Function(String);

class StandardState<C, E> extends State<C, E> {
  const StandardState(value,
      {context,
      actions,
      activities = const <String, bool>{},
      children,
      changed = false})
      : super(value,
            context: context,
            actions: actions,
            activities: activities,
            children: children,
            changed: changed);

  static StateMatcher createStateMatcher(String value) {
    return (String stateValue) => stateValue == value;
  }

  @override
  bool matches(String stateValue) => stateValue == value.toStateValue();

  @override
  String toString() => this.value.toString();
}

class StandardStateFactory<C, E> extends StateFactory<C, E> {
  @override
  State<C, E> createFromStateTreeNode(StateTreeNode<C, E> treeNode) =>
      StandardState<C, E>(treeNode);

  State<C, E> createState(
      StateTreeNode<C, E> tree, List<Action<C, E>> actions, C context,
      {Map<String, bool> activities = const {}, List<Service<C, E>> children}) {
    return StandardState(tree,
        context: context,
        actions:
            actions.where((action) => !(action is ActionAssign<C, E>)).toList(),
        activities: activities,
        children: children,
        changed: !actions.isEmpty ||
            actions.fold<bool>(
                false,
                (bool changed, Action<C, E> action) =>
                    changed || (action is ActionAssign)));
  }
}
