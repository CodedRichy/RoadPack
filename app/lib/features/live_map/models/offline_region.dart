import '../../../l10n/l10n.dart';

/// A slippy-map tile address (XYZ scheme, Web Mercator).
class TileCoordinate {
  const TileCoordinate({required this.x, required this.y, required this.z});

  final int x;
  final int y;
  final int z;

  String get key => '$z/$x/$y';

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  factory TileCoordinate.fromJson(Map<String, dynamic> json) => TileCoordinate(
    x: json['x'] as int,
    y: json['y'] as int,
    z: json['z'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is TileCoordinate && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'TileCoordinate($z/$x/$y)';
}

enum OfflineRegionStatus {
  /// Planned but nothing fetched. This is the honest resting state today.
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

extension OfflineRegionStatusLabel on OfflineRegionStatus {
  String label(AppLocalizations l10n) {
    switch (this) {
      case OfflineRegionStatus.notDownloaded:
        return l10n.mapRegionStatusNotDownloaded;
      case OfflineRegionStatus.downloading:
        return l10n.mapRegionStatusDownloading;
      case OfflineRegionStatus.downloaded:
        return l10n.mapRegionStatusDownloaded;
      case OfflineRegionStatus.failed:
        return l10n.mapRegionStatusFailed;
    }
  }
}

/// Measured cache occupancy. These are real byte counts of what is stored,
/// never a projection — see [OfflineRegionPlan] for the estimated side.
class TileCacheStats {
  const TileCacheStats({required this.tileCount, required this.bytes});

  final int tileCount;
  final int bytes;

  bool get isEmpty => tileCount == 0 && bytes == 0;

  /// Always false: this figure is measured, not modelled.
  bool get bytesAreEstimated => false;

  String get formattedSize => formatBytes(bytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }

  @override
  bool operator ==(Object other) =>
      other is TileCacheStats &&
      other.tileCount == tileCount &&
      other.bytes == bytes;

  @override
  int get hashCode => Object.hash(tileCount, bytes);
}
