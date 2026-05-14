import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/features/ews_ai/domain/gempa_model.dart';
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
    String mapSubtitle = 'Memuat status peta...';
    IconData mapIcon = Icons.map;
    Color mapBadgeColor = AppColors.primary;
    bool isMapAvailable = true;

    if (isCacheReady) {
      mapTitle = 'Peta Evakuasi (Offline Ready)';
      mapSubtitle = 'Aman, jalur tersedia tanpa internet';
      mapIcon = Icons.offline_pin;
      mapBadgeColor = AppColors.success;
    } else if (hasInternet) {
      mapTitle = 'Peta (Live Online)';
      mapSubtitle = 'Menggunakan data untuk memuat peta';
      mapIcon = Icons.wifi;
      mapBadgeColor = AppColors.info;
    } else {
      mapTitle = 'Peta Belum Tersedia';
      mapSubtitle = 'Tidak ada internet & belum diunduh';
      mapIcon = Icons.wifi_off;
      mapBadgeColor = AppColors.danger;
      isMapAvailable = false;
    }

    ref.listen<AsyncValue<EwsAlertData?>>(ewsProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final userLoc = ref.read(userLocationStreamProvider).value;
        _showEwsAlertModal(context, next.value!, isMapAvailable, userLoc);
      }
    });

    ref.listen<AsyncValue<String?>>(notificationPayloadProvider, (
      previous,
      next,
    ) {
      if (next.hasValue && next.value != null) {
        final payload = next.value!;

        context.go('/');

        if (payload == 'MOCK_TSUNAMI') {
          final dummyGempa = GempaModel(
            tanggal: 'Hari Ini',
            jam: 'Baru Saja',
            dateTime: DateTime.now().toIso8601String(),
            coordinates: '-8.50, 109.00',
            magnitude: '8.5',
            kedalaman: '10 km',
            wilayah: '150 km Barat Daya KAB-PANGANDARAN',
            potensi: 'Berpotensi TSUNAMI untuk diteruskan pada masyarakat',
            dirasakan: 'V-VI Pangandaran',
            shakemapUrl: '',
          );
          ref
              .read(ewsProvider.notifier)
              .triggerMockThreat(
                dummyGempa: dummyGempa,
                dummyIsDiZonaMerah: true,
              );
        } else if (payload == 'REAL_EWS') {
          ref.read(ewsProvider.notifier).checkLatestThreat();
        }
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
                              final userLoc = ref.read(userLocationStreamProvider).value;
                              _showEwsAlertModal(
                                context,
                                alertData!,
                                isMapAvailable,
                                userLoc,
                              );
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

  void _showEwsAlertModal(
    BuildContext context,
    EwsAlertData alertData,
    bool isMapAvailable,
    LatLng? userLocation,
  ) {
    final result = alertData.triageResult;
    final gempa = alertData.gempa;
    final isEvakuasi = result.statusTindakan == 'EVAKUASI';
    final themeColor = isEvakuasi ? AppColors.danger : AppColors.warning;
    final themeLightColor = isEvakuasi
        ? AppColors.dangerLight
        : AppColors.background;
    final alertTitle = isEvakuasi ? 'POTENSI TSUNAMI' : 'GEMPA BUMI';
    final alertSubtitle = isEvakuasi
        ? 'STATUS: AWAS (HIGH ALERT)'
        : 'STATUS: WASPADA';
    final zoneText = isEvakuasi
        ? 'LOKASI ANDA: ZONA MERAH TSUNAMI'
        : 'LOKASI ANDA: AMAN DARI TSUNAMI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (context) {
        return SizedBox(
          height: double.infinity,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: themeLightColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: themeColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'SUAR EWS ALERT',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Icon(Icons.warning, color: themeLightColor),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 260,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              height: 220,
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: AppColors.border,
                              ),
                              child: (userLocation != null && isMapAvailable)
                                  ? ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: userLocation,
                                          initialZoom: 15.0,
                                          interactionOptions: const InteractionOptions(
                                            flags: InteractiveFlag.none,
                                          ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/topo_bg.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child: Icon(Icons.map_outlined, color: AppColors.textHint, size: 48),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: themeColor,
                                      child: const Icon(
                                        Icons.warning,
                                        size: 24,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      alertTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: themeColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      alertSubtitle,
                                      style: TextStyle(
                                        color: themeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                                  Icon(
                                    Icons.circle,
                                    color: themeColor,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      zoneText,
                                      style: TextStyle(
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
                                    subValue: 'Update',
                                    isRed: isEvakuasi,
                                    themeColor: themeColor,
                                  ),
                                  const Divider(),
                                  _buildListStatRow(
                                    icon: Icons.waves,
                                    label: 'KEDALAMAN',
                                    value: gempa.kedalaman,
                                    subValue: 'Data BMKG',
                                    isRed: false,
                                    themeColor: themeColor,
                                  ),
                                  const Divider(),
                                  _buildListStatRow(
                                    icon: Icons.near_me_outlined,
                                    label: 'JARAK EPISENTRUM',
                                    value:
                                        '${alertData.distanceKm.toStringAsFixed(1)} km',
                                    subValue: 'Dari Anda',
                                    isRed: isEvakuasi,
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
                                      Icon(
                                        Icons.psychology,
                                        color: AppColors.white,
                                      ),
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          if (isMapAvailable) {
                                            Navigator.pop(context);
                                            context.push('/map');
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Peta tidak tersedia! Harap ikuti instruksi dari AI.',
                                                ),
                                                backgroundColor:
                                                    AppColors.warning,
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
            ],
          ),
        );
      },
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
                Text(
                  subValue,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
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
