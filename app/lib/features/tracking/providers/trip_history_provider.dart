import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/tracking_database.dart';
import '../services/tracking_service.dart';

final tripHistoryProvider = FutureProvider<List<Trip>>((ref) async {
  final db = ref.watch(trackingDatabaseProvider);
  return db.getCompletedTrips();
});
