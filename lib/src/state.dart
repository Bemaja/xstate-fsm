import 'actions.dart';
import 'tree.dart';

typedef StateMatcher = bool Function(String);

class State<C, E> {
  final StateTreeNode<C, E> value;
  final List<Action<C, E>> actions;
  final C context;
  final bool changed;
  final Map<String, bool> activities;
  final List<dynamic> children;

  const State(this.value,
      {this.context = null,
      this.actions = const [],
      this.activities = const {},
      this.children = const [],
      this.changed = false});

  static StateMatcher createStateMatcher(String value) {
    return (String stateValue) => stateValue == value;
  }

  bool matches(String stateValue) => stateValue == value.toStateValue();

  @override
  String toString() => this.value.toString();
}
