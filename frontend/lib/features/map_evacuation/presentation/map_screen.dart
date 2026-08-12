import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/core/theme/app_colors.dart';
import 'package:suar_app/features/map_evacuation/presentation/map_provider.dart';
import '../data/smart_evacuation_service.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../../ews_ai/presentation/ews_provider.dart';
import 'risk_map_screen.dart' show RippleMarker;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  /// Mem-parsing string koordinat "lat,lng" milik gempa aktif menjadi
  /// [LatLng]. Mengembalikan null jika format tidak valid atau hasilnya
  /// (0.0, 0.0) — supaya marker tidak pernah muncul di titik kosong.
  LatLng? _parseGempaPoint(String coordinates) {
    final coords = coordinates.split(',');
    if (coords.length < 2) return null;

    final lat = double.tryParse(coords[0].trim());
    final lng = double.tryParse(coords[1].trim());
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null;

    return LatLng(lat, lng);
  }

  /// Warna marker mengikuti ambang magnitude yang sama dengan yang dipakai
  /// untuk "TITIK GEMPA LIVE" di risk_map_screen.dart, supaya style-nya
  /// konsisten di kedua peta.
  Color _gempaColorForMagnitude(String magnitudeStr) {
    final magnitude = double.tryParse(magnitudeStr) ?? 0.0;
    if (magnitude >= 5.0) return AppColors.danger;
    if (magnitude >= 3.0) return AppColors.warning;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(userLocationStreamProvider);
    final routeAsync = ref.watch(evacuationRouteProvider);
    final ewsState = ref.watch(ewsProvider);

    LatLng? activeGempaPoint;
    Color activeGempaColor = AppColors.danger;
    final alertData = ewsState.value;
    if (alertData != null) {
      activeGempaPoint = _parseGempaPoint(alertData.gempa.coordinates);
      activeGempaColor = _gempaColorForMagnitude(alertData.gempa.magnitude);
    }

    ref.listen<AsyncValue<LatLng>>(userLocationStreamProvider, (prev, next) {
      if (_isMapReady && next.hasValue && next.value != null) {
        _mapController.move(next.value!, _mapController.camera.zoom);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text("Katakan Peta!")),
      body: locationAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Mencari sinyal satelit GPS...'),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text('Gagal memuat lokasi: $err')),
        data: (currentLocation) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentLocation,
                  initialZoom: 16,
                  onMapReady: () {
                    setState(() {
                      _isMapReady = true;
                    });
                  },
                ),
                children: [
                  // base map layer
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.suar.app',
                    tileProvider: FMTCTileProvider(
                      stores: const {
                        'evacuation_map': BrowseStoreStrategy.read,
                      },
                    ),
                  ),

                  if (routeAsync.hasValue &&
                      routeAsync.value != null &&
                      routeAsync.value!.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routeAsync.value!,
                          color: AppColors.primary,
                          strokeWidth: 5,
                          strokeJoin: StrokeJoin.round,
                        ),
                      ],
                    ),

                  // user position layer
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.5,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // titik episentrum gempa yang sedang memicu alert aktif
                  // (hanya 1 titik statis, style sama seperti "TITIK GEMPA
                  // LIVE" di risk_map_screen.dart — tidak ada toggle/opsi
                  // tambahan)
                  if (activeGempaPoint != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: activeGempaPoint,
                          width: 60,
                          height: 60,
                          child: RippleMarker(color: activeGempaColor),
                        ),
                      ],
                    ),
                ],
              ),

              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: routeAsync.when(
                  data: (routeData) {
                    if (routeData == null) {
                      return Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.waves,
                                color: AppColors.primary,
                              ),
                            ),
                            title: const Text(
                              'Simulasi Evakuasi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Bencana Tsunami',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                ref
                                    .read(evacuationRouteProvider.notifier)
                                    .findRouteManual();
                              },
                              child: const Text('CARI RUTE'),
                            ),
                          ),
                        ),
                      );
                    }

                    return Card(
                      color: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'RUTE AMAN DITEMUKAN',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ikuti garis rute pada peta menuju dataran tinggi. Segera tinggalkan area pesisir sekarang juga!',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Card(
                    color: AppColors.surface,
                    child: ListTile(
                      leading: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text(
                        'Menganalisis Topografi...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Mencari rute ke dataran tinggi terdekat',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  error: (err, stack) {
                    if (err is VerticalEvacuationException) {
                      return Card(
                        color: AppColors.danger,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.white,
                                    size: 28,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'EVAKUASI VERTIKAL!',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                err.message,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Card(
                      color: AppColors.warningLight,
                      child: ListTile(
                        leading: const Icon(
                          Icons.wifi_off,
                          color: AppColors.warning,
                        ),
                        title: const Text('Gagal membuat rute darat'),
                        subtitle: Text(
                          err.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),

              Positioned(
                bottom: 24,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'recenter_fab',
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _isMapReady
                      ? () {
                          _mapController.move(currentLocation, 16.0);
                        }
                      : null,
                  child: const Icon(Icons.center_focus_strong),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
