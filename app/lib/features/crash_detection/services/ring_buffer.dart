class RingBuffer<T> {
  RingBuffer(this.capacity) : _buffer = List<T?>.filled(capacity, null);

  final int capacity;
  final List<T?> _buffer;
  int _head = 0;
  int _count = 0;

  int get length => _count;
  bool get isFull => _count == capacity;
  bool get isEmpty => _count == 0;

  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
  }

  List<T> toList() {
    if (_count == 0) return [];
    final result = <T>[];
    final start = _count < capacity ? 0 : _head;
    for (var i = 0; i < _count; i++) {
      result.add(_buffer[(start + i) % capacity] as T);
    }
    return result;
  }

  List<T> window(int n) {
    final items = toList();
    if (n >= items.length) return items;
    return items.sublist(items.length - n);
  }

  void clear() {
    _head = 0;
    _count = 0;
    _buffer.fillRange(0, capacity, null);
  }
}
