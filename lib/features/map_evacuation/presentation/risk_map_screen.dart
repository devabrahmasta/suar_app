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

final showLandslideProvider = NotifierProvider<LandslideLayerNotifier, bool>(() {
  return LandslideLayerNotifier();
});

class RiskMapScreen extends ConsumerWidget {
  const RiskMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(userLocationStreamProvider);
    
    final showTsunami = ref.watch(showTsunamiProvider);
    final showLandslide = ref.watch(showLandslideProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Risiko Bencana'),
        backgroundColor: AppColors.surface,
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
                options: MapOptions(
                  initialCenter: currentLocation,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.suar.app',
                  ),
                  
                  if (showTsunami)
                    Opacity(
                      opacity: 0.6,
                      child: TileLayer(
                        urlTemplate: 'https://gis.bnpb.go.id/server/rest/services/inarisk/tsunami_bahaya/MapServer/tile/{z}/{y}/{x}',
                      ),
                    ),

                  if (showLandslide)
                    Opacity(
                      opacity: 0.6,
                      child: TileLayer(
                        urlTemplate: 'https://gis.bnpb.go.id/server/rest/services/inarisk/layer_bahaya_tanah_longsor_30/MapServer/tile/{z}/{y}/{x}',
                      ),
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
                            child: Icon(Icons.my_location, color: AppColors.info, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Positioned(
                top: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: AppColors.white.withValues(alpha: 0.9),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "PILIH LAYER",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        
                        _LayerToggle(
                          label: "Tsunami",
                          value: showTsunami,
                          activeColor: AppColors.primary,
                          onChanged: (val) => ref.read(showTsunamiProvider.notifier).setLayer(val),
                        ),
                        
                        _LayerToggle(
                          label: "Longsor",
                          value: showLandslide,
                          activeColor: AppColors.warning,
                          onChanged: (val) => ref.read(showLandslideProvider.notifier).setLayer(val),
                        ),
                      ],
                    ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}