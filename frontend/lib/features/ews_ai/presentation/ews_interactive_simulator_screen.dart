import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:suar_app/core/services/suar_backend_service.dart';
import 'package:suar_app/features/ews_ai/presentation/ews_provider.dart';
import '../../../core/theme/app_colors.dart';

class EwsInteractiveSimulatorScreen extends ConsumerStatefulWidget {
  const EwsInteractiveSimulatorScreen({super.key});

  @override
  ConsumerState<EwsInteractiveSimulatorScreen> createState() =>
      _EwsInteractiveSimulatorScreenState();
}

class _EwsInteractiveSimulatorScreenState
    extends ConsumerState<EwsInteractiveSimulatorScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  LatLng? _epicenter;
  double _magnitude = 6.5;
  String _depth = "15 km";
  String _potensi = "Berpotensi TSUNAMI untuk diteruskan pada masyarakat";
  String _wilayah = "Lautan Selatan Jawa (Simulasi)";
  bool _isLoading = false;

  final TextEditingController _depthController =
      TextEditingController(text: "15 km");
  final TextEditingController _wilayahController =
      TextEditingController(text: "Lautan Selatan Jawa (Simulasi)");

  @override
  void initState() {
    super.initState();
    _depthController.addListener(() {
      _depth = _depthController.text;
    });
    _wilayahController.addListener(() {
      _wilayah = _wilayahController.text;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final locService = ref.read(locationServiceProvider);
        final pos = await locService.getCurrentPosition();
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          // Default epicenter is offset slightly south to Yogyakarta waters
          _epicenter = LatLng(pos.latitude - 1.2, pos.longitude - 0.5);
        });
        _mapController.move(_userLocation!, 7.5);
      } catch (e) {
        debugPrint('Simulator GPS Error: $e');
        // Fallback default coordinates if GPS fails
        setState(() {
          _userLocation = const LatLng(-7.79, 110.36);
          _epicenter = const LatLng(-8.90, 109.80);
        });
      }
    });
  }

  @override
  void dispose() {
    _depthController.dispose();
    _wilayahController.dispose();
    super.dispose();
  }

  double _calculateLocalRadiusInMeters() {
    final isTsunami =
        _potensi.toLowerCase().contains('tsunami') || _magnitude >= 6.5;
    
    double baseRadius = 50000.0;
    if (isTsunami) {
      baseRadius = 250000.0;
    } else if (_magnitude >= 6.0) {
      baseRadius = 150000.0;
    } else if (_magnitude >= 5.5) {
      baseRadius = 100000.0;
    }

    // Parsing kedalaman (menghapus " km" jika ada)
    final depthVal = double.tryParse(_depth.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 10.0;

    if (depthVal >= 70.0) {
      return baseRadius * 0.5; // Reduksi 50% untuk gempa dalam (>= 70 km)
    } else if (depthVal >= 30.0) {
      return baseRadius * 0.75; // Reduksi 25% untuk gempa menengah (30 - 69 km)
    }
    return baseRadius; // Gempa dangkal (<30 km) memiliki radius dampak maksimal
  }

  double _calculateDistanceInKm() {
    if (_userLocation == null || _epicenter == null) return 0.0;
    return Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          _epicenter!.latitude,
          _epicenter!.longitude,
        ) /
        1000.0;
  }

  Future<void> _triggerSimulation() async {
    if (_epicenter == null) return;
    setState(() {
      _isLoading = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final distance = _calculateDistanceInKm();
    final radius = _calculateLocalRadiusInMeters() / 1000.0;
    final isInside = distance <= radius;

    try {
      final backendService = ref.read(suarBackendServiceProvider);
      final result = await backendService.simulateAlert(
        magnitude: _magnitude,
        depth: _depth,
        latitude: _epicenter!.latitude,
        longitude: _epicenter!.longitude,
        potensi: _potensi,
        wilayah: _wilayah,
      );

      final int impacted = result['impactedCount'] ?? 0;

      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚡ GEMPA SIMULASI BERHASIL DILUNCURKAN!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Radius Spasial: ${result['radiusInKm']} KM | Penerima: $impacted Perangkat.\n'
                'Status Jarak Anda: ${distance.toStringAsFixed(1)} KM (${isInside ? "DI DALAM" : "DI LUAR"} radius)',
              ),
            ],
          ),
          backgroundColor: isInside ? AppColors.success : AppColors.info,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'OK',
            textColor: AppColors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Simulasi Gagal: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistanceInKm();
    final radius = _calculateLocalRadiusInMeters() / 1000.0;
    final isInside = distance <= radius;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulator Gempa Spasial'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          // 1. Map Section
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? const LatLng(-7.79, 110.36),
                    initialZoom: 7.5,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _epicenter = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.suar_app',
                    ),
                    if (_userLocation != null && _epicenter != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_userLocation!, _epicenter!],
                            color: isInside ? AppColors.success : AppColors.textSecondary,
                            strokeWidth: 3.0,
                          ),
                        ],
                      ),
                    if (_epicenter != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _epicenter!,
                            radius: _calculateLocalRadiusInMeters(),
                            useRadiusInMeter: true,
                            color: AppColors.danger.withValues(alpha: 0.15),
                            borderColor: AppColors.danger.withValues(alpha: 0.6),
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        if (_epicenter != null)
                          Marker(
                            point: _epicenter!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.danger,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Text(
                      'Ketuk Peta untuk Memindah Episentrum 📍',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Control Form Section
          Expanded(
            flex: 5,
            child: Container(
              color: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Distance feedback header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isInside
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isInside
                            ? AppColors.danger.withValues(alpha: 0.3)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isInside ? Icons.warning_amber_rounded : Icons.info_outline,
                          color: isInside ? AppColors.danger : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jarak Anda: ${distance.toStringAsFixed(1)} KM (Radius: ${radius.toStringAsFixed(0)} KM)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isInside
                                    ? 'STATUS: DI DALAM RADIUS DAMPAK (Alarm Sirene akan berbunyi di HP Anda!)'
                                    : 'STATUS: DI LUAR RADIUS DAMPAK (Aman / Notifikasi diabaikan)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isInside
                                      ? AppColors.danger
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Magnitude Slider
                  Text(
                    'Magnitudo Gempa: ${_magnitude.toStringAsFixed(1)} Mw',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _magnitude,
                    min: 5.0,
                    max: 9.0,
                    divisions: 40,
                    activeColor: AppColors.danger,
                    label: '${_magnitude.toStringAsFixed(1)} Mw',
                    onChanged: (val) {
                      setState(() {
                        _magnitude = val;
                      });
                    },
                  ),

                  // Tsunami dropdown
                  const Text(
                    'Potensi Tsunami',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _potensi,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value:
                            'Berpotensi TSUNAMI untuk diteruskan pada masyarakat',
                        child: Text('Berpotensi Tsunami'),
                      ),
                      DropdownMenuItem(
                        value: 'Tidak berpotensi tsunami',
                        child: Text('Tidak Berpotensi Tsunami'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _potensi = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Depth & Location fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _depthController,
                          decoration: const InputDecoration(
                            labelText: 'Kedalaman Gempa',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _wilayahController,
                          decoration: const InputDecoration(
                            labelText: 'Wilayah / Episentrum',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Trigger Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _triggerSimulation,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.flash_on),
                      label: Text(
                        _isLoading
                            ? 'Memproses di Server PostGIS...'
                            : 'LUNCURKAN GEMPA SIMULASI (TEST EWS)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
