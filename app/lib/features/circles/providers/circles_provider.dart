import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circle.dart';
import '../services/circle_repository.dart';

final circlesProvider = AsyncNotifierProvider<CirclesNotifier, List<Circle>>(
  CirclesNotifier.new,
);

class CirclesNotifier extends AsyncNotifier<List<Circle>> {
  @override
  Future<List<Circle>> build() async {
    final repo = ref.watch(circleRepositoryProvider);
    if (repo == null) return [];
    return repo.fetchCircles();
  }

  Future<void> refresh() async {
    final repo = ref.read(circleRepositoryProvider);
    if (repo == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.fetchCircles());
  }
}
