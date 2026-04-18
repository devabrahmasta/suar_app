import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../ews_ai/presentation/ews_provider.dart';
import '../data/map_cache_service.dart';
import 'map_provider.dart';

enum GeofenceState { safe, transit, dwelling }

class GeofenceNotifier extends AsyncNotifier<GeofenceState> {
  Timer? _dwellTimer;
  LatLng? _lastKnownLocation;

  @override
  Future<GeofenceState> build() async {
    ref.listen(ewsProvider, (previous, next) {
      if (next.hasValue && next.value?.statusTindakan == 'EVAKUASI') {
        _triggerEmergencyOverride();
      }
    });

    ref.listen(userLocationStreamProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _handleLocationUpdate(next.value!);
      }
    });

    return GeofenceState.safe;
  }

  Future<void> _handleLocationUpdate(LatLng location) async {
    final networkState = await ref.read(networkStatusProvider.future);
    final hasInternet = !networkState.contains(ConnectivityResult.none);

    if (!hasInternet) {
      _dwellTimer?.cancel();
      return; 
    }

    _lastKnownLocation = location;
    final inariskService = ref.read(inariskServiceProvider);
    
    final isRedZone = await inariskService.checkTsunamiHazard(location.latitude, location.longitude);
    final currentState = state.value ?? GeofenceState.safe;

    if (isRedZone && currentState == GeofenceState.safe) {
      state = const AsyncData(GeofenceState.transit);
      _startDwellTimer(location);
      
    } else if (!isRedZone && currentState != GeofenceState.safe) {
      _dwellTimer?.cancel();
      state = const AsyncData(GeofenceState.safe);
      print("Geofence: Batal unduh, pengguna hanya lewat.");
    }
  }

  void _startDwellTimer(LatLng location) {
    _dwellTimer?.cancel();
    
    _dwellTimer = Timer(const Duration(seconds: 15), () async {
      state = const AsyncData(GeofenceState.dwelling);
      print("Geofence: Waktu singgah tercapai. Mulai sinkronisasi peta...");
      await _downloadAndCacheMap(location);
    });
  }

  Future<void> _triggerEmergencyOverride() async {
    if (_lastKnownLocation == null) return;

    final inariskService = ref.read(inariskServiceProvider);
    final isRedZone = await inariskService.checkTsunamiHazard(_lastKnownLocation!.latitude, _lastKnownLocation!.longitude);
    
    if (isRedZone && state.value != GeofenceState.dwelling) {
      print("Geofence: EMERGENCY OVERRIDE! Memaksa unduhan peta sekarang!");
      _dwellTimer?.cancel();
      state = const AsyncData(GeofenceState.dwelling);
      await _downloadAndCacheMap(_lastKnownLocation!);
    }
  }

  Future<void> _downloadAndCacheMap(LatLng location) async {
    final networkState = await ref.read(networkStatusProvider.future);
    final hasInternet = !networkState.contains(ConnectivityResult.none);
    
    if (!hasInternet) {
      print("Geofence: Batal sinkronisasi peta karena internet tiba-tiba terputus.");
      return;
    }

    try {
      final cacheService = MapCacheService();
      final smartEvacuation = ref.read(smartEvacuationProvider);
      
      List<LatLng>? route;
      try {
        route = await smartEvacuation.findOptimalRoute(location);
        await cacheService.saveOfflineRoute(route);
      } catch (e) {
        print('Geofence (Evakuasi Vertikal): $e');
      }

      if (route != null && route.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints([location, ...route]);
        const distance = Distance();
        final sw = distance.offset(bounds.southWest, 1000, 225);
        final ne = distance.offset(bounds.northEast, 1000, 45);
        await cacheService.downloadMapBoundingBox(LatLngBounds(sw, ne));
      } else {
        await cacheService.downloadMapRadius(location, radiusInMeters: 3000);
      }
      
      ref.invalidate(mapCacheStatusProvider);
      print("Geofence: Peta Dynamic & Rute sukses diamankan!");
    } catch (e) {
      print("Geofence Cache Error: $e");
    }
  }
}

final geofenceProvider = AsyncNotifierProvider<GeofenceNotifier, GeofenceState>(() {
  return GeofenceNotifier();
});