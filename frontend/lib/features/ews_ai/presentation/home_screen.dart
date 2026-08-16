import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suar_app/features/map_evacuation/presentation/geofence_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/alert_text_utils.dart';
import '../domain/triage_result_model.dart';
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

    // Saat mode EVAKUASI aktif, card "Peta Evakuasi" di bawah disembunyikan
    // (kartu alert merah sudah punya tombol "BUKA PETA EVAKUASI" sendiri),
    // biar nggak ada dua jalan ke peta yang bikin bingung.
    final isEvakuasiActive =
        ewsState.value?.triageResult.statusTindakan == 'EVAKUASI';

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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(ewsProvider.notifier).checkLatestThreat(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ewsState.when(
                data: (alertData) {
                  if (alertData == null) {
                    return _buildStatusCard(
                      color: AppColors.successLight,
                      iconColor: AppColors.success,
                      icon: Icons.check_circle,
                      title: 'Tidak ada peringatan aktif',
                      subtitle: 'Kondisi saat ini aman dan terkendali.',
                    );
                  }
                  return _buildAlertCard(
                    context,
                    alertData,
                    isMapAvailable: isMapAvailable,
                  );
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

              if (!isEvakuasiActive) ...[
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
              ],

              _buildGempaTerkiniCard(ref),
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

  Widget _buildAlertCard(
    BuildContext context,
    EwsAlertData alertData, {
    required bool isMapAvailable,
  }) {
    final result = alertData.triageResult;
    final gempa = alertData.gempa;
    final isEvakuasi = result.statusTindakan == 'EVAKUASI';
    final bgColor = isEvakuasi ? AppColors.danger : AppColors.warning;
    final headline = resolveAlertHeadline(
      gempa.potensi,
      fallback: isEvakuasi ? 'POTENSI TSUNAMI' : 'PERINGATAN GEMPA BUMI',
    );
    final statusLine =
        'STATUS: ${result.statusTindakan} · '
        '${isEvakuasi ? "ZONA MERAH TSUNAMI" : "ZONA WASPADA"}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.priority_high_rounded, color: bgColor),
              ),
              const SizedBox(height: 14),
              Text(
                headline,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusLine,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: bgColor,
                    elevation: 0,
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
                            'Peta tidak dapat diakses tanpa internet! Unduh terlebih dahulu saat online.',
                          ),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'BUKA PETA EVAKUASI',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => context.push('/alert'),
                  child: const Text(
                    'Lihat rincian peringatan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLakukanSekarangCard(result),
      ],
    );
  }

  Widget _buildLakukanSekarangCard(TriageResult result) {
    final steps = result.tindakanSegera;
    if (steps.isEmpty) return const SizedBox.shrink();

    final remaining = steps.length - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LAKUKAN SEKARANG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps.first,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$remaining langkah berikutnya ada di rincian peringatan.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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

  Color _magnitudeChipColor(double magnitude) {
    if (magnitude >= 5.0) return AppColors.danger;
    if (magnitude >= 3.0) return AppColors.warning;
    return AppColors.info;
  }

  Widget _buildMagnitudeChip(String magnitude) {
    final value = double.tryParse(magnitude) ?? 0.0;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _magnitudeChipColor(value).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        magnitude,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  /// BMKG ngirim jam dengan detik + suffix "WIB" (mis. "17:31:37 WIB").
  /// Zona waktunya udah jelas dari lokasi, jadi cukup tampilkan HH:mm biar
  /// list-nya nggak sesak.
  String _formatJam(String jam) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(jam);
    if (match == null) return jam;
    return '${match.group(1)}:${match.group(2)}';
  }

  Widget _buildGempaTerkiniCard(WidgetRef ref) {
    final recentQuakesAsync = ref.watch(recentEarthquakesProvider);
    final quakes = recentQuakesAsync.value ?? const [];
    final limited = quakes.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GEMPA TERKINI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textHint,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'BMKG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (limited.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                recentQuakesAsync.isLoading
                    ? 'Memuat data gempa...'
                    : 'Belum ada data gempa terbaru',
                style: const TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < limited.length; i++) ...[
              if (i > 0) const Divider(height: 24, color: AppColors.border),
              _buildGempaRow(limited[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildGempaRow(Map<String, dynamic> gempa) {
    final wilayah = gempa['Wilayah']?.toString() ?? 'Unknown Location';
    final magnitude = gempa['Magnitude']?.toString() ?? '-';
    final tanggal = gempa['Tanggal']?.toString() ?? '-';
    final jam = _formatJam(gempa['Jam']?.toString() ?? '-');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMagnitudeChip(magnitude),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wilayah,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tanggal,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          jam,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
