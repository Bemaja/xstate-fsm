import 'interfaces.dart';
import 'log.dart';

abstract class StandardNodeType<C, E> extends NodeType<C, E> {
  final StateTreeFactory<C, E> treeFactory;
  final Log log;

  const StandardNodeType(key, this.treeFactory, {this.log = const Log()})
      : super(key);

  @override
  bool get isLeafNode => true;

  @override
  bool get isFinal => false;

  @override
  StateTreeType<C, E> transitionFromTree(
      StateTreeNode<C, E> initialStateTreeNode,
      {StateTreeNode<C, E> oldTree,
      StateTreeNode<C, E> childBranch}) {
    log.fine(this, () => "Leaf does not transition");

    return treeFactory.createTreeNodeType();
  }

  @override
  StateTreeType<C, E> selectStateTree(
          {String key, StateTreeNode<C, E> childBranch}) =>
      treeFactory.createTreeNodeType();

  @override
  StateNode<C, E> selectTargetNode(String key) => throw Exception(
      "Unable to retrieve child state '${key}' from ...; no child states exist."); /* path(...):  '${id}' */

  String toString() => "${NodeType}(${key})";
}

class NodeTypeAtomic<C, E> extends StandardNodeType<C, E> {
  const NodeTypeAtomic(key, treeFactory, {strict = false})
      : super(key, treeFactory);
}

class NodeTypeFinal<C, E> extends StandardNodeType<C, E> {
  const NodeTypeFinal(key, treeFactory, {strict = false})
      : super(key, treeFactory);

  @override
  bool get isFinal => true;
}

class NodeTypeHistory<C, E> extends StandardNodeType<C, E> {
  const NodeTypeHistory(key, treeFactory, {strict = false})
      : super(key, treeFactory);
}

class NodeTypeParallel<C, E> extends StandardNodeType<C, E> {
  final Map<String, StateNode<C, E>> states;

  const NodeTypeParallel(key, treeFactory, {this.states, strict = false})
      : super(key, treeFactory);

  @override
  bool get isLeafNode => false;

  @override
  StateTreeType<C, E> transitionFromTree(
          StateTreeNode<C, E> initialStateTreeNode,
          {StateTreeNode<C, E> oldTree,
          StateTreeNode<C, E> childBranch}) =>
      treeFactory.createTreeNodeType(
          children: states.values
              .map<StateTreeNode<C, E>>((StateNode<C, E> stateNode) {
        if (childBranch != null && childBranch.matches(stateNode)) {
          return childBranch;
        } else if (oldTree.hasBranch(stateNode)) {
          return oldTree.getBranch(stateNode);
        }
        return stateNode.initialStateTreeNode;
      }).toList());

  @override
  StateTreeType<C, E> selectStateTree(
          {String key, StateTreeNode<C, E> childBranch}) =>
      treeFactory.createTreeNodeType(
          children: states.values
              .map<StateTreeNode<C, E>>((StateNode<C, E> stateNode) {
        if (childBranch.matches(stateNode)) {
          return childBranch;
        }
        return stateNode.initialStateTreeNode;
      }).toList());
}

class NodeTypeCompound<C, E> extends StandardNodeType<C, E> {
  final Map<String, StateNode<C, E>> states;

  const NodeTypeCompound(key, treeFactory, {this.states})
      : super(key, treeFactory);

  @override
  bool get isLeafNode => false;

  @override
  StateTreeType<C, E> transitionFromTree(
      StateTreeNode<C, E> initialStateTreeNode,
      {StateTreeNode<C, E> oldTree,
      StateTreeNode<C, E> childBranch}) {
    if (childBranch != null) {
      StateTreeType<C, E> childTree =
          treeFactory.createTreeNodeType(children: [childBranch]);
      log.fine(this, () => "Created child tree ${childTree}");
      return childTree;
    }
    StateTreeType<C, E> initialTree =
        treeFactory.createTreeNodeType(children: [initialStateTreeNode]);
    log.fine(this, () => "Created initial tree ${initialTree}");
    return initialTree;
  }

  @override
  StateTreeType<C, E> selectStateTree(
      {String key, StateTreeNode<C, E> childBranch}) {
    if (childBranch != null) {
      return treeFactory.createTreeNodeType(children: [childBranch]);
    }
    if (key != null) {
      if (states.containsKey(key)) {
        return treeFactory
            .createTreeNodeType(children: [states[key].initialStateTreeNode]);
      }
      throw Exception("${key} is missing on substates!");
    }
    if (states.keys.length > 0) {
      return treeFactory.createTreeNodeType(
          children: [states[states.keys.first].initialStateTreeNode]);
    }
    if (states.keys.length > 1) {
      throw Exception(
          "You provided no valid state key for a compound node with several substates!"
          /* path(...):  '${id}' */
          );
    }

    return treeFactory.createTreeNodeType();
  }

  @override
  StateNode<C, E> selectTargetNode(String key) {
    if (states.containsKey(key)) {
      return states[key];
    }

    throw Exception(
        "Child state '${key}' does not exist on ..."); /* path(...):  '${id}' */
  }
}
