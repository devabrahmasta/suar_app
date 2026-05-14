import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class HomeLocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const HomeLocationPickerScreen({super.key, required this.initialLocation});

  @override
  State<HomeLocationPickerScreen> createState() =>
      _HomeLocationPickerScreenState();
}

class _HomeLocationPickerScreenState extends State<HomeLocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  String _currentAddress = "Mencari alamat...";
  Timer? _debounce;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialLocation;
    _fetchAddress(_currentCenter);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _fetchAddress(LatLng position) async {
    if (!mounted) return;
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': position.latitude,
          'lon': position.longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'suar_app/1.0'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final displayName = response.data['display_name'] as String?;
        if (mounted) {
          setState(() {
            _currentAddress = displayName ?? "Alamat tidak ditemukan";
          });
        }
      } else {
        if (mounted) setState(() => _currentAddress = "Gagal mengambil alamat");
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = "Gagal mengambil alamat");
    }
  }

  void _onConfirmLocation() {
    Navigator.pop(context, (_currentCenter, _currentAddress));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: AppColors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 16.0,
              maxZoom: 18.0,
              onPositionChanged: (position, hasGesture) {
                if (_currentAddress != "Mencari alamat...") {
                  setState(() => _currentAddress = "Mencari alamat...");
                }

                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 800), () {
                  _fetchAddress(_currentCenter);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.suar_app',
              ),
            ],
          ),
          // Fixed Center Pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0),
              child: Icon(Iconsax.location, size: 40, color: AppColors.primary),
            ),
          ),
          // Bottom Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set Lokasi Rumah',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Iconsax.location, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _currentAddress == "Mencari alamat..."
                          ? null
                          : _onConfirmLocation,
                      child: _currentAddress == "Mencari alamat..."
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text(
                              'Pilih Lokasi Ini',
                              style: TextStyle(
                                fontSize: 16,
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
