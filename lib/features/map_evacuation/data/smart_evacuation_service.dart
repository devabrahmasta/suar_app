import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/features/map_evacuation/data/river_service.dart';
import '../../ews_ai/data/inarisk_service.dart';
import 'elevation_service.dart';
import 'routing_service.dart';

class VerticalEvacuationException implements Exception {
  final String message;
  VerticalEvacuationException(this.message);
  @override
  String toString() => message;
}

class SmartEvacuationService {
  final InaRiskService inarisk;
  final ElevationService elevationService;
  final RoutingService routingService;
  final RiverService riverService;

  SmartEvacuationService({
    required this.inarisk,
    required this.elevationService,
    required this.routingService,
    required this.riverService,
  });

  Future<List<LatLng>> findOptimalRoute(LatLng currentLocation) async {
    final List<double> searchRadii = [3000.0, 2000.0, 2000.0];
    final List<double> bearings = [0, 45, 90, 135, 180, 225, 270, 315];

    const distanceCalculator = Distance();

    debugPrint('\n=== MULAI ANALISIS RUTE EVAKUASI (HYBRID SNAP) ===');

    for (double radius in searchRadii) {
      List<Map<String, dynamic>> validCandidates = [];

      final futures = bearings.map((bearing) async {
        try {
          final LatLng candidatePoint = distanceCalculator.offset(
            currentLocation,
            radius,
            bearing,
          );

          final isRedZone = await inarisk.checkTsunamiHazard(
            candidatePoint.latitude,
            candidatePoint.longitude,
          );
          if (isRedZone) {
            debugPrint('Arah $bearing°: Di Zona Merah InaRISK');
            return null;
          }

          final elevation = await elevationService.getElevation(candidatePoint);
          if (elevation <= 5.0) {
            debugPrint('Arah $bearing°: Elevasi rendah ($elevation m)');
            return null;
          }

          debugPrint('Arah $bearing° lolos! (Elevasi: $elevation m)');
          return {
            'point': candidatePoint,
            'elevation': elevation,
            'bearing': bearing,
          };
        } catch (e) {
          return null;
        }
      });

      final results = await Future.wait(futures);
      for (var res in results) {
        if (res != null) validCandidates.add(res);
      }

      debugPrint('\nTotal kandidat kasar: ${validCandidates.length}');

      if (validCandidates.isNotEmpty) {
        validCandidates.sort(
          (a, b) =>
              (b['elevation'] as double).compareTo(a['elevation'] as double),
        );

        for (var candidate in validCandidates) {
          final bearing = candidate['bearing'];
          final originalPoint = candidate['point'] as LatLng;
          debugPrint('\nMengeksekusi kandidat terbaik arah $bearing°...');

          final snappedPoint = await routingService.getSnappedPoint(
            originalPoint,
          );
          if (snappedPoint == null) {
            debugPrint(
              'Arah $bearing° diabaikan: Tidak ada akses jalan pejalan kaki terdekat (Terisolasi).',
            );
            continue;
          }

          final isSnappedRedZone = await inarisk.checkTsunamiHazard(
            snappedPoint.latitude,
            snappedPoint.longitude,
          );
          if (isSnappedRedZone) {
            debugPrint(
              'Arah $bearing° diabaikan: Titik jalan mundur ke Zona Merah Tsunami!',
            );
            continue;
          }

          final snappedElevation = await elevationService.getElevation(
            snappedPoint,
          );
          if (snappedElevation <= 5.0) {
            debugPrint(
              'Arah $bearing° diabaikan: Jalan raya berada di elevasi rendah ($snappedElevation m).',
            );
            continue;
          }

          try {
            debugPrint(
              'Validasi sukses! Membangun rute ke jalan aspal arah $bearing°...',
            );
            final route = await routingService.getEvacuationRoute(
              currentLocation,
              snappedPoint,
            );

            debugPrint(
              'Memvalidasi keamanan jalur rute dari sungai di dataran rendah...',
            );
            bool isRouteSafe = true;

            int step = (route.length / 10).ceil();
            if (step < 1) step = 1;

            for (int i = 0; i < route.length; i += step) {
              final routePoint = route[i];
              final pointElevation = await elevationService.getElevation(
                routePoint,
              );

              if (pointElevation <= 10.0) {
                final isCrossingRiver = await riverService.isNearRiver(
                  routePoint,
                  radius: 50,
                );

                if (isCrossingRiver) {
                  debugPrint(
                    'Rute arah $bearing° digugurkan: Di pertengahan jalan memotong/melewati sungai pada elevasi rendah ($pointElevation mdpl).',
                  );
                  isRouteSafe = false;
                  break;
                }
              }
            }

            if (!isRouteSafe) {
              continue;
            }

            debugPrint('RUTE EVAKUASI DITEMUKAN!');
            return route;
          } catch (e) {
            debugPrint(
              'Rute darat gagal dibuat (kemungkinan terhalang sungai): $e',
            );
            continue;
          }
        }
      }
    }

    debugPrint(
      'KESIMPULAN: Semua titik jalan kaki gagal. Harus evakuasi vertikal.',
    );
    throw VerticalEvacuationException(
      'Tidak ditemukan rute darat yang aman. Lakukan Evakuasi Vertikal ke gedung tinggi terdekat!',
    );
  }
}
