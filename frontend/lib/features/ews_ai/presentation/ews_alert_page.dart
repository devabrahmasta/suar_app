import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../map_evacuation/presentation/map_provider.dart';
import 'ews_provider.dart';

/// Halaman penuh untuk menampilkan peringatan EWS aktif.
///
/// Menggantikan showModalBottomSheet lama (_showEwsAlertModal di
/// home_screen.dart) agar bisa dibuka dari kondisi apapun (cold-start,
/// warm-resume, tap notifikasi, atau trigger foreground) lewat route
/// '/alert' — bukan lewat parameter navigasi. Semua data diambil
/// langsung dari [ewsProvider].
///
/// Visual DI-HARDCODE ke skema "ada evakuasi" (Skenario 1) terlepas dari
/// status tindakan asli — hanya konten (judul, subjudul, zona, angka
/// fakta, wilayah) yang tetap dinamis sesuai data.
class EwsAlertPage extends ConsumerWidget {
  const EwsAlertPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ewsAsync = ref.watch(ewsProvider);
    final alertData = ewsAsync.value;

    // Tidak ada alert aktif saat page ini dibuka (mis. diakses langsung,
    // atau state sempat berubah jadi null) -> jangan crash, redirect ke
    // Home setelah frame ini selesai.
    if (alertData == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/');
        }
      });
      return const Scaffold(backgroundColor: AppColors.background);
    }

    final isCacheReady = ref.watch(mapCacheStatusProvider).value ?? false;
    final networkState =
        ref.watch(networkStatusProvider).value ?? [ConnectivityResult.none];
    final hasInternet = !networkState.contains(ConnectivityResult.none);
    final isMapAvailable = isCacheReady || hasInternet;

    final userLocation = ref.watch(userLocationStreamProvider).value;

    final result = alertData.triageResult;
    final gempa = alertData.gempa;
    final isEvakuasi = result.statusTindakan == 'EVAKUASI';

    // Skema visual di-hardcode ke versi "ada evakuasi" (Skenario 1),
    // tidak peduli status tindakan asli.
    const themeColor = AppColors.primary;
    const themeLightColor = AppColors.dangerLight;

    // Konten tetap dinamis mengikuti data asli.
    final alertTitle = isEvakuasi ? 'POTENSI TSUNAMI' : 'GEMPA BUMI';
    final alertSubtitle = isEvakuasi
        ? 'STATUS: AWAS (HIGH ALERT)'
        : 'STATUS: WASPADA';
    final zoneText = isEvakuasi
        ? 'LOKASI ANDA: ZONA MERAH TSUNAMI'
        : 'LOKASI ANDA: AMAN DARI TSUNAMI';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: themeLightColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: themeColor),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'SUAR EWS ALERT',
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.warning, color: themeLightColor),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 295,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: const BoxDecoration(color: AppColors.border),
                      child: (userLocation != null && isMapAvailable)
                          ? FlutterMap(
                              options: MapOptions(
                                initialCenter: userLocation,
                                initialZoom: 15.0,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.suar.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: userLocation,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Image.asset(
                              'assets/images/topo_bg.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.map_outlined,
                                      color: AppColors.textHint,
                                      size: 48,
                                    ),
                                  ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: themeColor,
                              child: Icon(
                                Icons.sensors,
                                size: 24,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              alertTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: themeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alertSubtitle,
                              style: const TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Card(
                              elevation: 0,
                              color: themeColor.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: themeColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 18,
                                      color: themeColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        gempa.wilayah.isNotEmpty
                                            ? 'Titik Gempa: ${gempa.wilayah}'
                                            : 'Titik Gempa: Lokasi belum tersedia dari BMKG',
                                        style: const TextStyle(
                                          color: themeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.circle, color: themeColor, size: 12),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              zoneText,
                              style: const TextStyle(
                                color: themeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildListStatRow(
                            icon: Icons.sensors,
                            label: 'MAGNITUDE',
                            value: '${gempa.magnitude} SR',
                            subValue: '*tingkat kekuatan gempa bumi',
                            isRed: true,
                            themeColor: themeColor,
                          ),
                          const Divider(),
                          _buildListStatRow(
                            icon: Icons.waves,
                            label: 'KEDALAMAN',
                            value: gempa.kedalaman,
                            subValue: '*kedalaman pusat titik gempa',
                            isRed: true,
                            themeColor: themeColor,
                          ),
                          const Divider(),
                          _buildListStatRow(
                            icon: Icons.near_me_outlined,
                            label: 'JARAK EPISENTRUM',
                            value:
                                '${alertData.distanceKm.toStringAsFixed(1)} km',
                            subValue: '*jarak titik gempa dengan anda',
                            isRed: true,
                            themeColor: themeColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology, color: AppColors.white),
                              SizedBox(width: 8),
                              Text(
                                'AI RECOMMENDATION',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Tindakan Segera:',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionList(result.tindakanSegera),

                          const SizedBox(height: 12),

                          const Text(
                            'Persiapan:',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionList(result.persiapan),

                          const SizedBox(height: 24),

                          if (isEvakuasi)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isMapAvailable
                                      ? AppColors.white
                                      : AppColors.surface,
                                  foregroundColor: isMapAvailable
                                      ? themeColor
                                      : AppColors.textHint,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () {
                                  if (isMapAvailable) {
                                    context.push('/map');
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Peta tidak tersedia! Harap ikuti instruksi dari AI.',
                                        ),
                                        backgroundColor: AppColors.warning,
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(
                                  isMapAvailable
                                      ? Icons.location_on
                                      : Icons.location_off,
                                ),
                                label: Text(
                                  isMapAvailable
                                      ? 'BUKA PETA EVAKUASI'
                                      : "PETA TIDAK TERSEDIA",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListStatRow({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required bool isRed,
    required Color themeColor,
  }) {
    final activeColor = isRed ? themeColor : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRed
                  ? themeColor.withValues(alpha: 0.1)
                  : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isRed ? themeColor : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subValue,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: activeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
