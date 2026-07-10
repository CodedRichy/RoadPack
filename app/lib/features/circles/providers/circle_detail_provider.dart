import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circle.dart';
import '../models/circle_member.dart';
import '../services/circle_repository.dart';
import 'circles_provider.dart';

class CircleDetail {
  const CircleDetail({
    required this.circle,
    required this.members,
    required this.observers,
  });

  final Circle circle;
  final List<CircleMember> members;
  final List<EmergencyContact> observers;

  int get totalCount => members.length + observers.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleDetail &&
          circle == other.circle &&
          _listEquals(members, other.members) &&
          _listEquals(observers, other.observers);

  @override
  int get hashCode => Object.hash(circle, members.length, observers.length);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final circleDetailProvider =
    FutureProvider.family<CircleDetail, String>((ref, circleId) async {
  final repo = ref.watch(circleRepositoryProvider);
  if (repo == null) {
    throw StateError('Not authenticated');
  }

  final circles = ref.read(circlesProvider).valueOrNull ?? [];
  Circle circle;
  try {
    circle = circles.firstWhere((c) => c.id == circleId);
  } catch (_) {
    circle = await repo.fetchCircle(circleId);
  }

  final members = await repo.fetchMembers(circleId);
  final observers = await repo.fetchObservers(circleId);

  return CircleDetail(
    circle: circle,
    members: members,
    observers: observers,
  );
});
