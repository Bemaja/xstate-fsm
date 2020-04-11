abstract class ContextFactory<C> {
  C fromMap(Map<String, dynamic> map);

  C copy(C original);
}
