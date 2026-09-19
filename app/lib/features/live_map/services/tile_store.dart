import '../models/offline_region.dart';

/// Byte storage for cached map tiles.
///
/// Kept behind an interface for one honest reason: the app currently has no
/// filesystem plugin (`path_provider` is not a dependency), so there is no
/// durable on-device implementation yet. [InMemoryTileStore] is real and
/// works, but it does not survive a process restart — which is exactly the
/// case offline mode exists for. Swapping in a durable store is a one-class
/// change once the dependency lands.
abstract class TileStore {
  Future<void> put(TileCoordinate tile, List<int> bytes, {String? regionId});

  Future<List<int>?> get(TileCoordinate tile);

  Future<bool> contains(TileCoordinate tile);

  Future<TileCacheStats> stats();

  Future<void> clear();

  Future<void> clearRegion(String regionId);

  /// True when tiles written here survive an app restart.
  bool get isDurable;
}

/// Process-lifetime tile store. Honest about not being durable.
class InMemoryTileStore implements TileStore {
  final Map<String, List<int>> _tiles = {};
  final Map<String, String?> _regions = {};

  @override
  bool get isDurable => false;

  @override
  Future<void> put(
    TileCoordinate tile,
    List<int> bytes, {
    String? regionId,
  }) async {
    _tiles[tile.key] = List<int>.unmodifiable(bytes);
    _regions[tile.key] = regionId;
  }

  @override
  Future<List<int>?> get(TileCoordinate tile) async => _tiles[tile.key];

  @override
  Future<bool> contains(TileCoordinate tile) async =>
      _tiles.containsKey(tile.key);

  @override
  Future<TileCacheStats> stats() async {
    var bytes = 0;
    for (final v in _tiles.values) {
      bytes += v.length;
    }
    return TileCacheStats(tileCount: _tiles.length, bytes: bytes);
  }

  @override
  Future<void> clear() async {
    _tiles.clear();
    _regions.clear();
  }

  @override
  Future<void> clearRegion(String regionId) async {
    final doomed = _regions.entries
        .where((e) => e.value == regionId)
        .map((e) => e.key)
        .toList();
    for (final key in doomed) {
      _tiles.remove(key);
      _regions.remove(key);
    }
  }
}
