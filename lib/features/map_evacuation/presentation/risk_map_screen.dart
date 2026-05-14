import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suar_app/core/theme/app_colors.dart';
import 'map_provider.dart';

class TsunamiLayerNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setLayer(bool value) {
    state = value;
  }
}

final showTsunamiProvider = NotifierProvider<TsunamiLayerNotifier, bool>(() {
  return TsunamiLayerNotifier();
});

class LandslideLayerNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setLayer(bool value) {
    state = value;
  }
}

final showLandslideProvider = NotifierProvider<LandslideLayerNotifier, bool>(
  () {
    return LandslideLayerNotifier();
  },
);

class EarthquakeLayerNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setLayer(bool value) {
    state = value;
  }
}

final showEarthquakeProvider = NotifierProvider<EarthquakeLayerNotifier, bool>(() {
  return EarthquakeLayerNotifier();
});

class RiskMapScreen extends ConsumerStatefulWidget {
  const RiskMapScreen({super.key});

  @override
  ConsumerState<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends ConsumerState<RiskMapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(userLocationStreamProvider);

    final showTsunami = ref.watch(showTsunamiProvider);
    final showLandslide = ref.watch(showLandslideProvider);
    final showEarthquake = ref.watch(showEarthquakeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Peta Risiko Bencana'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: locationAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat lokasi Anda...'),
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
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.suar.app',
                  ),

                  if (showTsunami)
                    TileLayer(
                      urlTemplate:
                          'https://gis.bnpb.go.id/server/rest/services/inarisk/layer_bahaya_tsunami/ImageServer/tile/{z}/{y}/{x}',
                    ),

                  if (showLandslide)
                    TileLayer(
                      urlTemplate:
                          'https://gis.bnpb.go.id/server/rest/services/inarisk/layer_bahaya_tanah_longsor/ImageServer/tile/{z}/{y}/{x}',
                    ),

                  if (showEarthquake)
                    TileLayer(
                      urlTemplate:
                          'https://gis.bnpb.go.id/server/rest/services/inarisk/layer_bahaya_gempabumi/ImageServer/tile/{z}/{y}/{x}',
                    ),

                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.infoLight.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              color: AppColors.info,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Positioned(
                bottom: 240,
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () {
                    _mapController.move(currentLocation, 14.0);
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),

              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Legenda Peta",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LayerToggle(
                        label: "Zona Bahaya Tsunami",
                        value: showTsunami,
                        activeColor: AppColors.primary,
                        onChanged: (val) => ref
                            .read(showTsunamiProvider.notifier)
                            .setLayer(val),
                      ),
                      _LayerToggle(
                        label: "Zona Bahaya Longsor",
                        value: showLandslide,
                        activeColor: AppColors.primary,
                        onChanged: (val) => ref
                            .read(showLandslideProvider.notifier)
                            .setLayer(val),
                      ),
                      _LayerToggle(
                        label: "Titik Gempa Live",
                        value: showEarthquake,
                        activeColor: AppColors.primary,
                        onChanged: (val) => ref
                            .read(showEarthquakeProvider.notifier)
                            .setLayer(val),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _LayerToggle({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            height: 32,
            child: Switch(
              value: value,
              activeColor: AppColors.white,
              activeTrackColor: activeColor,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
