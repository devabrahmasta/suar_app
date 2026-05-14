import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/core/theme/app_colors.dart';
import 'map_provider.dart';
import '../../ews_ai/presentation/ews_provider.dart';

// --- LAYER NOTIFIERS ---
class TsunamiLayerNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLayer(bool value) => state = value;
}

final showTsunamiProvider = NotifierProvider<TsunamiLayerNotifier, bool>(
  () => TsunamiLayerNotifier(),
);

class LandslideLayerNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLayer(bool value) => state = value;
}

final showLandslideProvider = NotifierProvider<LandslideLayerNotifier, bool>(
  () => LandslideLayerNotifier(),
);

class EarthquakeLayerNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void setLayer(bool value) => state = value;
}

final showEarthquakeProvider = NotifierProvider<EarthquakeLayerNotifier, bool>(
  () => EarthquakeLayerNotifier(),
);

// --- MAIN SCREEN ---
class RiskMapScreen extends ConsumerStatefulWidget {
  const RiskMapScreen({super.key});

  @override
  ConsumerState<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends ConsumerState<RiskMapScreen> {
  final MapController _mapController = MapController();

  bool _isTsunamiLoading = false;
  bool _isInTsunamiZone = false;

  bool _isLandslideLoading = false;
  bool _isInLandslideZone = false;

  void _showEarthquakeDetails(
    BuildContext context,
    Map<String, dynamic> gempa,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          maxChildSize: 0.5,
          minChildSize: 0.2,
          builder: (context, scrollController) {
            final wilayah = gempa['Wilayah'] ?? 'Unknown Location';
            final magnitude = gempa['Magnitude'] ?? '-';
            final tanggal = gempa['Tanggal'] ?? '-';
            final jam = gempa['Jam'] ?? '-';
            final kedalaman = gempa['Kedalaman'] ?? '-';
            final potensi = gempa['Potensi'] ?? '-';
            final isTsunami = potensi.toLowerCase().contains('tsunami');

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    wilayah,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        magnitude,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: color,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Magnitudo',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Waktu', '$tanggal $jam'),
                  const SizedBox(height: 12),
                  _buildDetailRow('Kedalaman', kedalaman),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isTsunami
                          ? AppColors.dangerLight
                          : AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      potensi,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isTsunami ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Data: BMKG',
                    style: TextStyle(fontSize: 10, color: AppColors.textHint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showLegendBottomSheet(BuildContext context, LatLng currentLocation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Consumer(
              builder: (context, ref, child) {
                final showTsunami = ref.watch(showTsunamiProvider);
                final showLandslide = ref.watch(showLandslideProvider);
                final showEarthquake = ref.watch(showEarthquakeProvider);

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        "Legenda Peta",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _LayerToggle(
                        label: "Zona Bahaya Tsunami",
                        value: showTsunami,
                        activeColor: AppColors.primary,
                        isLoading: _isTsunamiLoading,
                        onChanged: (val) async {
                          ref.read(showTsunamiProvider.notifier).setLayer(val);
                          if (val) {
                            setStateModal(() => _isTsunamiLoading = true);
                            this.setState(() => _isTsunamiLoading = true);
                            final inarisk = ref.read(inariskServiceProvider);
                            final result = await inarisk.checkTsunamiHazard(
                              currentLocation.latitude,
                              currentLocation.longitude,
                            );
                            if (mounted) {
                              this.setState(() {
                                _isInTsunamiZone = result;
                                _isTsunamiLoading = false;
                              });
                              setStateModal(() => _isTsunamiLoading = false);
                            }
                          } else {
                            if (mounted) {
                              this.setState(() => _isInTsunamiZone = false);
                            }
                          }
                        },
                      ),
                      _LayerToggle(
                        label: "Zona Bahaya Longsor",
                        value: showLandslide,
                        activeColor: AppColors.primary,
                        isLoading: _isLandslideLoading,
                        onChanged: (val) async {
                          ref
                              .read(showLandslideProvider.notifier)
                              .setLayer(val);
                          if (val) {
                            setStateModal(() => _isLandslideLoading = true);
                            this.setState(() => _isLandslideLoading = true);
                            final inarisk = ref.read(inariskServiceProvider);
                            final result = await inarisk.checkLandslideHazard(
                              currentLocation.latitude,
                              currentLocation.longitude,
                            );
                            if (mounted) {
                              this.setState(() {
                                _isInLandslideZone = result;
                                _isLandslideLoading = false;
                              });
                              setStateModal(() => _isLandslideLoading = false);
                            }
                          } else {
                            if (mounted) {
                              this.setState(() => _isInLandslideZone = false);
                            }
                          }
                        },
                      ),
                      _LayerToggle(
                        label: "Titik Gempa Live",
                        value: showEarthquake,
                        activeColor: AppColors.primary,
                        onChanged: (val) => ref
                            .read(showEarthquakeProvider.notifier)
                            .setLayer(val),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Data zona bahaya bersumber dari InaRISK BNPB. Ketersediaan data bergantung pada server BNPB.",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(userLocationStreamProvider);
    final recentQuakesAsync = ref.watch(recentEarthquakesProvider);

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
                  initialZoom: 5.0, // Di-zoom out sedikit agar gempa terlihat
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.suar.app',
                  ),

                  // LAYER TSUNAMI (Circle overlay)
                  if (showTsunami && _isInTsunamiZone)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: currentLocation,
                          radius: 3000, // 3000 meters
                          useRadiusInMeter: true,
                          color: AppColors.danger.withValues(alpha: 0.3),
                          borderColor: AppColors.danger.withValues(alpha: 0.5),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),

                  // LAYER LONGSOR (Circle overlay)
                  if (showLandslide && _isInLandslideZone)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: currentLocation,
                          radius: 3000, // 3000 meters
                          useRadiusInMeter: true,
                          color: AppColors.warning.withValues(alpha: 0.3),
                          borderColor: AppColors.warning.withValues(alpha: 0.5),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),

                  // TITIK GEMPA LIVE (Dari BMKG - Ripple Markers)
                  if (showEarthquake && recentQuakesAsync.value != null)
                    MarkerLayer(
                      markers: recentQuakesAsync.value!.map((gempa) {
                        final coordsStr = gempa['Coordinates'] as String? ?? '';
                        final coords = coordsStr.split(',');
                        LatLng point = const LatLng(0, 0);
                        if (coords.length == 2) {
                          point = LatLng(
                            double.tryParse(coords[0].trim()) ?? 0.0,
                            double.tryParse(coords[1].trim()) ?? 0.0,
                          );
                        }

                        final magStr = gempa['Magnitude'] as String? ?? '0';
                        final magnitude = double.tryParse(magStr) ?? 0.0;

                        Color markerColor = AppColors.info;
                        if (magnitude >= 5.0) {
                          markerColor = AppColors.danger;
                        } else if (magnitude >= 3.0) {
                          markerColor = AppColors.warning;
                        }

                        return Marker(
                          point: point,
                          width: 60,
                          height: 60,
                          child: GestureDetector(
                            onTap: () => _showEarthquakeDetails(
                              context,
                              gempa,
                              markerColor,
                            ),
                            child: RippleMarker(color: markerColor),
                          ),
                        );
                      }).toList(),
                    ),

                  // TITIK LOKASI USER
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
                              Iconsax.gps,
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

              // Positioned(
              //   bottom: 240,
              //   right: 16,
              //   child:
              // ),
              Positioned(
                bottom: 24,
                right: 16,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: 'legend_fab',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed: () =>
                          _showLegendBottomSheet(context, currentLocation),
                      child: const Icon(Icons.layers),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      backgroundColor: AppColors.surface,
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- RIPPLE MARKER FOR EARTHQUAKES ---
class RippleMarker extends StatefulWidget {
  final Color color;
  const RippleMarker({super.key, required this.color});

  @override
  State<RippleMarker> createState() => _RippleMarkerState();
}

class _RippleMarkerState extends State<RippleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(
            color: widget.color,
            animationValue: _animation.value,
          ),
          size: const Size(60, 60),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _RipplePainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ripple (fades out and scales up)
    final outerScale = 0.4 + (0.6 * animationValue);
    final outerOpacity = 0.4 * (1.0 - animationValue);
    final outerRadius = (size.width / 2) * outerScale;

    final outerPaint = Paint()
      ..color = color.withValues(alpha: outerOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, outerRadius, outerPaint);

    // Middle circle (semi-transparent)
    final middlePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.25, middlePaint);

    // Inner circle (solid dot)
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.1, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}

class _LayerToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;
  final bool isLoading;

  const _LayerToggle({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
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
