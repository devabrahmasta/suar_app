import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suar_app/features/map_evacuation/presentation/geofence_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'ews_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../map_evacuation/presentation/map_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ewsState = ref.watch(ewsProvider);
    ref.watch(geofenceProvider);

    final isCacheReady = ref.watch(mapCacheStatusProvider).value ?? false;
    final networkState =
        ref.watch(networkStatusProvider).value ?? [ConnectivityResult.none];
    final hasInternet = !networkState.contains(ConnectivityResult.none);

    String mapTitle = 'Peta Evakuasi';
    IconData mapIcon = Icons.map;
    Color mapBadgeColor = AppColors.primary;
    bool isMapAvailable = true;

    if (isCacheReady) {
      mapTitle = 'Peta Evakuasi (Offline Ready)';
      mapIcon = Icons.offline_pin;
      mapBadgeColor = AppColors.success;
    } else if (hasInternet) {
      mapTitle = 'Peta (Live Online)';
      mapIcon = Icons.wifi;
      mapBadgeColor = AppColors.info;
    } else {
      mapTitle = 'Peta Belum Tersedia';
      mapIcon = Icons.wifi_off;
      mapBadgeColor = AppColors.danger;
      isMapAvailable = false;
    }

    ref.listen<AsyncValue<EwsAlertData?>>(ewsProvider, (previous, next) {
      if (!next.isLoading &&
          next.hasValue &&
          next.value != null &&
          previous?.value?.gempa.dateTime != next.value?.gempa.dateTime) {
        context.push('/alert');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/suar_logo.png', height: 32),
            const SizedBox(width: 8),
            Text('SUAR', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_active,
              color: AppColors.primary,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
            ),
            onPressed: () => ref.read(ewsProvider.notifier).checkLatestThreat(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ewsState.when(
              data: (alertData) {
                final result = alertData?.triageResult;
                if (result == null) {
                  return _buildStatusCard(
                    color: AppColors.successLight,
                    iconColor: AppColors.success,
                    icon: Icons.check_circle,
                    title: 'Tidak ada peringatan aktif',
                    subtitle: 'Kondisi saat ini aman dan terkendali.',
                  );
                } else {
                  final isEvakuasi = result.statusTindakan == 'EVAKUASI';
                  final bgColor = isEvakuasi
                      ? AppColors.danger
                      : AppColors.warning;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.white,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isEvakuasi ? 'POTENSI TSUNAMI' : 'POTENSI GEMPA',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Peringatan dini aktif. Segera ambil tindakan!',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.white,
                              foregroundColor: bgColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              context.push('/alert');
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_run_rounded),
                                const SizedBox(width: 8),
                                const Text(
                                  'LIHAT INSTRUKSI AI & RUTE',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
              loading: () => _buildStatusCard(
                color: AppColors.infoLight,
                iconColor: AppColors.info,
                icon: Icons.sync,
                title: 'Menganalisis Cuaca & Seismik',
                subtitle: 'Menunggu respon dari AI dan BMKG...',
              ),
              error: (err, stack) => _buildStatusCard(
                color: AppColors.surface,
                iconColor: AppColors.textHint,
                icon: Icons.signal_wifi_off,
                title: 'Gagal Menghubungi Server',
                subtitle: 'Sistem beralih ke mode offline sepenuhnya.',
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(mapIcon, color: mapBadgeColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mapTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 150,
                    width: double.infinity,
                    color: AppColors.border,
                    child: isMapAvailable
                        ? Consumer(
                            builder: (context, ref, child) {
                              final locationAsync = ref.watch(
                                userLocationStreamProvider,
                              );
                              return locationAsync.when(
                                data: (currentLocation) => FlutterMap(
                                  options: MapOptions(
                                    initialCenter: currentLocation,
                                    initialZoom: 15.0,
                                    interactionOptions:
                                        const InteractionOptions(
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
                                          point: currentLocation,
                                          width: 30,
                                          height: 30,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight
                                                  .withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.my_location,
                                                color: AppColors.primary,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                error: (err, stack) => const Center(
                                  child: Text(
                                    'Gagal memuat cuplikan peta',
                                    style: TextStyle(
                                      color: AppColors.textHint,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  color: AppColors.textHint,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Peta ditangguhkan (Mode Offline)',
                                  style: TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: isMapAvailable
                            ? () => context.push('/map')
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Peta tidak dapat diakses tanpa internet! Unduh terlebih dahulu saat online.',
                                    ),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fullscreen,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Buka Peta Layar Penuh',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'SUMBER DAYA PASCA-EVAKUASI',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push('/first-aid'),
                    child: _buildResourceButton(
                      Icons.medical_services,
                      'P3K Dasar',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push('/emergency-numbers'),
                    child: _buildResourceButton(
                      Icons.contact_phone,
                      'Nomor Darurat',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
