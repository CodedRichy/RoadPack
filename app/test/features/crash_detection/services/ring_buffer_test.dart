import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/crash_detection/services/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('adds items up to capacity', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      expect(buffer.toList(), [1, 2, 3]);
      expect(buffer.isFull, true);
      expect(buffer.length, 3);
    });

    test('overwrites oldest on overflow', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      buffer.add(4);
      expect(buffer.toList(), [2, 3, 4]);
      expect(buffer.length, 3);
    });

    test('window returns last N items', () {
      final buffer = RingBuffer<int>(5);
      for (var i = 1; i <= 5; i++) {
        buffer.add(i);
      }
      expect(buffer.window(3), [3, 4, 5]);
      expect(buffer.window(1), [5]);
      expect(buffer.window(10), [1, 2, 3, 4, 5]);
    });

    test('window works after overflow', () {
      final buffer = RingBuffer<int>(3);
      for (var i = 1; i <= 7; i++) {
        buffer.add(i);
      }
      expect(buffer.toList(), [5, 6, 7]);
      expect(buffer.window(2), [6, 7]);
    });

    test('clear resets buffer', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.isFull, false);
      expect(buffer.toList(), isEmpty);
    });

    test('empty buffer returns empty list', () {
      final buffer = RingBuffer<int>(5);
      expect(buffer.toList(), isEmpty);
      expect(buffer.window(3), isEmpty);
      expect(buffer.length, 0);
    });

    test('single capacity buffer', () {
      final buffer = RingBuffer<int>(1);
      buffer.add(1);
      expect(buffer.toList(), [1]);
      buffer.add(2);
      expect(buffer.toList(), [2]);
    });
  });
}
