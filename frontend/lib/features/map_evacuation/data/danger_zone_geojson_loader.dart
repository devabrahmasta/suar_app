import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/core/theme/app_colors.dart';

/// Aset zona bahaya tsunami hasil simplifikasi, di-gzip agar lebih ringan
/// untuk dibundel & dimuat.
const String _dangerZoneAssetPath =
    'assets/json/zona_merah_simplified.geojson.gz';

/// Cache di memori — file cuma di-decompress & di-parse sekali per sesi
/// app, walau dipanggil dari beberapa halaman (Risk Map & EWS Map).
Future<List<Polygon>>? _cachedDangerZonePolygons;

Future<List<Polygon>> loadDangerZonePolygons() {
  return _cachedDangerZonePolygons ??= _parseDangerZoneGeoJson();
}

Future<List<Polygon>> _parseDangerZoneGeoJson() async {
  try {
    final byteData = await rootBundle.load(_dangerZoneAssetPath);
    final compressedBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    // Hasil decompress geojson ini ~2.2MB (detail garis pantai Jawa &
    // Bali), jadi parsing-nya dilempar ke isolate terpisah lewat compute()
    // supaya tidak nge-block UI thread.
    return await compute(_decodeDangerZonePolygons, compressedBytes);
  } catch (e) {
    // Fail-safe: kalau file hilang/rusak/format tak terduga, layer cukup
    // kosong (tidak tampil) — jangan sampai bikin peta atau app crash.
    return const [];
  }
}

List<Polygon> _decodeDangerZonePolygons(Uint8List compressedBytes) {
  final decompressedBytes = gzip.decode(compressedBytes);
  final raw = utf8.decode(decompressedBytes);

  final data = jsonDecode(raw) as Map<String, dynamic>;
  final features = (data['features'] as List?) ?? const [];

  final polygons = <Polygon>[];
  for (final feature in features) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) continue;

    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'];

    if (type == 'Polygon') {
      polygons.addAll(_polygonFromRings(coordinates as List));
    } else if (type == 'MultiPolygon') {
      for (final rings in (coordinates as List)) {
        polygons.addAll(_polygonFromRings(rings as List));
      }
    }
  }
  return polygons;
}

/// Ring pertama = exterior, ring selanjutnya (kalau ada) = lubang (holes).
List<Polygon> _polygonFromRings(List rings) {
  if (rings.isEmpty) return const [];

  final exterior = _ringToLatLng(rings.first as List);
  final holes = rings.length > 1
      ? rings.skip(1).map((r) => _ringToLatLng(r as List)).toList()
      : null;

  return [
    Polygon(
      points: exterior,
      holePointsList: holes,
      color: AppColors.danger.withValues(alpha: 0.25),
      borderColor: AppColors.danger,
      borderStrokeWidth: 1.5,
    ),
  ];
}

List<LatLng> _ringToLatLng(List ring) {
  return ring
      .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();
}
