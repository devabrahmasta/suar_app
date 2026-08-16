import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/core/theme/app_colors.dart';
import 'package:suar_app/core/widgets/icon_circle_badge.dart';
import 'map_provider.dart';

class RiskMapScreen extends ConsumerStatefulWidget {
  const RiskMapScreen({super.key});

  @override
  ConsumerState<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends ConsumerState<RiskMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const double _sheetMinSize = 0.14;
  static const double _sheetMaxSize = 0.65;
  static const List<double> _sheetSnapSizes = [
    _sheetMinSize,
    0.4,
    _sheetMaxSize,
  ];

  AnimationController? _moveController;

  @override
  void dispose() {
    _moveController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Color _magnitudeColor(double magnitude) {
    if (magnitude >= 5.0) return AppColors.danger;
    if (magnitude >= 3.0) return AppColors.warning;
    return AppColors.info;
  }

  LatLng? _parseGempaCoords(Map<String, dynamic> gempa) {
    final coordsStr = gempa['Coordinates'] as String? ?? '';
    final coords = coordsStr.split(',');
    if (coords.length != 2) return null;
    final lat = double.tryParse(coords[0].trim());
    final lng = double.tryParse(coords[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  /// Menganimasikan kamera peta secara halus ke [destLocation], lalu
  /// menjalankan [onComplete] setelah animasi selesai (mis. membuka
  /// detail gempa).
  void _animatedMapMove(
    LatLng destLocation,
    double destZoom, {
    VoidCallback? onComplete,
  }) {
    _moveController?.dispose();

    final camera = _mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

    final controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _moveController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (status == AnimationStatus.completed) onComplete?.call();
        controller.dispose();
        if (identical(_moveController, controller)) {
          _moveController = null;
        }
      }
    });

    controller.forward();
  }

  /// Saat item gempa di-tap: minimize dulu panel Gempa Terbaru supaya
  /// tidak menutupi peta, baru kamera bergerak ke titik gempa, lalu
  /// detail gempanya muncul.
  Future<void> _onGempaItemTap(Map<String, dynamic> gempa) async {
    final point = _parseGempaCoords(gempa);
    if (point == null) return;

    final magStr = gempa['Magnitude'] as String? ?? '0';
    final color = _magnitudeColor(double.tryParse(magStr) ?? 0.0);

    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        _sheetMinSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    if (!mounted) return;

    _animatedMapMove(
      point,
      12.0,
      onComplete: () {
        if (mounted) _showEarthquakeDetails(context, gempa, color);
      },
    );
  }

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

  String _formatCacheAge(DateTime? lastSync) {
    if (lastSync == null) return '—';
    final diff = DateTime.now().difference(lastSync);
    if (diff.inSeconds < 60) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }

  Widget _buildCacheBadge(DateTime? lastSync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Diperbarui ${_formatCacheAge(lastSync)}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  /// Menutup panel ke ukuran snap terdekat dari posisi drag saat ini.
  void _snapSheetToNearest() {
    if (!_sheetController.isAttached) return;
    final current = _sheetController.size;
    var nearest = _sheetSnapSizes.first;
    var minDiff = (current - nearest).abs();
    for (final size in _sheetSnapSizes) {
      final diff = (current - size).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = size;
      }
    }
    _sheetController.animateTo(
      nearest,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Drag handle (dash abu-abu) bisa langsung ditarik untuk stretch panel,
  /// tanpa harus melalui list (yang scroll-nya bisa bentrok dengan gesture
  /// resize saat konten sudah panjang).
  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (!_sheetController.isAttached) return;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final delta = details.primaryDelta ?? 0;
        final newSize = (_sheetController.size - delta / screenHeight).clamp(
          _sheetMinSize,
          _sheetMaxSize,
        );
        _sheetController.jumpTo(newSize);
      },
      onVerticalDragEnd: (_) => _snapSheetToNearest(),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildGempaListItem(Map<String, dynamic> gempa) {
    final wilayah = gempa['Wilayah']?.toString() ?? 'Unknown Location';
    final magnitude = gempa['Magnitude']?.toString() ?? '-';
    final jam = gempa['Jam']?.toString() ?? '-';
    final color = _magnitudeColor(double.tryParse(magnitude) ?? 0.0);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onGempaItemTap(gempa),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            IconCircleBadge(label: magnitude, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                wilayah,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              jam,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGempaTerbaruContent(ScrollController scrollController) {
    final recentQuakesAsync = ref.watch(recentEarthquakesProvider);
    final lastSync = ref.watch(lastGempaSyncProvider);
    final quakes = recentQuakesAsync.value ?? const [];
    final limited = quakes.take(15).toList();

    return Column(
      children: [
        _buildDragHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GEMPA TERBARU',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              _buildCacheBadge(lastSync),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: limited.isEmpty ? 1 : limited.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 20, color: AppColors.border),
            itemBuilder: (context, index) {
              if (limited.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      recentQuakesAsync.isLoading
                          ? 'Memuat data gempa...'
                          : 'Belum ada data gempa terbaru',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              return _buildGempaListItem(limited[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _sheetMinSize,
      minChildSize: _sheetMinSize,
      maxChildSize: _sheetMaxSize,
      snap: true,
      snapSizes: _sheetSnapSizes,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: _buildGempaTerbaruContent(scrollController),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(userLocationStreamProvider);
    final recentQuakesAsync = ref.watch(recentEarthquakesProvider);

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
                  initialZoom: 5.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.suar.app',
                  ),

                  // TITIK GEMPA LIVE
                  if (recentQuakesAsync.value != null)
                    MarkerLayer(
                      markers: recentQuakesAsync.value!.map((gempa) {
                        final point =
                            _parseGempaCoords(gempa) ?? const LatLng(0, 0);

                        final magStr = gempa['Magnitude'] as String? ?? '0';
                        final magnitude = double.tryParse(magStr) ?? 0.0;
                        final markerColor = _magnitudeColor(magnitude);

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

              Positioned(
                bottom: MediaQuery.sizeOf(context).height * _sheetMinSize + 16,
                right: 16,
                child: FloatingActionButton(
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
              ),

              Positioned.fill(child: _buildBottomPanel(context)),
            ],
          );
        },
      ),
    );
  }
}

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

    // Outer ripple
    final outerScale = 0.4 + (0.6 * animationValue);
    final outerOpacity = 0.4 * (1.0 - animationValue);
    final outerRadius = (size.width / 2) * outerScale;

    final outerPaint = Paint()
      ..color = color.withValues(alpha: outerOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, outerRadius, outerPaint);

    // Middle circle
    final middlePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.25, middlePaint);

    // Inner circle
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
