class Event<E> {
  final String type;
  final E event;

  const Event(this.type, {this.event});

  @override
  String toString() => "${Event}(${type})";
}
