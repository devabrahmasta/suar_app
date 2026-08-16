import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/alert_text_utils.dart';
import '../../map_evacuation/presentation/map_provider.dart';
import 'ews_provider.dart';

/// Halaman penuh untuk menampilkan peringatan EWS aktif.
///
/// Merespon data secara dinamis dari [ewsProvider] (GempaModel, TriageResult, & distanceKm)
/// dengan desain UI EWS Alert modern sesuai spesifikasi visual aplikasi Suar.
class EwsAlertPage extends ConsumerWidget {
  const EwsAlertPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ewsAsync = ref.watch(ewsProvider);
    final alertData = ewsAsync.value;

    // Tidak ada alert aktif -> redirect ke Home
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
    final lastEwsCheck = ref.watch(lastEwsCheckProvider);

    final result = alertData.triageResult;
    final gempa = alertData.gempa;
    final isEvakuasi = result.statusTindakan == 'EVAKUASI';

    // Penentuan Judul & Subjudul Peringatan secara dinamis
    final String alertTitle = resolveAlertHeadline(
      gempa.potensi,
      fallback: isEvakuasi ? 'POTENSI TSUNAMI' : 'PERINGATAN GEMPA BUMI',
    );

    final String alertSubtitle =
        'STATUS: ${result.statusTindakan} · ${isEvakuasi ? "ZONA MERAH TSUNAMI" : "ZONA WASPADA"}';

    // Penentuan Waktu Gempa Terjadi
    final String timeText = () {
      if (gempa.tanggal.isNotEmpty && gempa.jam.isNotEmpty) {
        return '${gempa.tanggal}, ${gempa.jam}';
      } else if (gempa.tanggal.isNotEmpty) {
        return gempa.tanggal;
      } else if (gempa.jam.isNotEmpty) {
        return gempa.jam;
      } else if (gempa.dateTime.isNotEmpty) {
        return gempa.dateTime;
      }
      return '';
    }();

    // Menggabungkan seluruh instruksi tindakan segera dan persiapan
    final List<String> allInstructions = [
      ...result.tindakanSegera,
      ...result.persiapan,
    ].where((item) => item.trim().isNotEmpty).toList();

    if (allInstructions.isEmpty) {
      allInstructions.add('Tetap waspada dan ikuti arahan pihak berwenang.');
    }

    const primaryAccent = AppColors.danger;
    const secondaryAccent = AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.dangerLight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: primaryAccent,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => context.go('/'),
            ),
          ),
        ),
        title: const Text(
          'SUAR EWS ALERT',
          style: TextStyle(
            color: primaryAccent,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Red Alert Banner Header (Kartu Peringatan Utama)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: primaryAccent,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: primaryAccent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.priority_high_rounded,
                          color: primaryAccent,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alertTitle,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alertSubtitle,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. BMKG Earthquake Details Card (Pusat Gempa)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PUSAT GEMPA · BMKG',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gempa.wilayah.isNotEmpty
                          ? gempa.wilayah
                          : 'Lokasi episentrum belum tersedia',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (timeText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Waktu: $timeText',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatBox(
                          label: 'MAGNITUDE',
                          value: gempa.magnitude.isNotEmpty
                              ? gempa.magnitude
                              : '-',
                        ),
                        const SizedBox(width: 10),
                        _buildStatBox(
                          label: 'KEDALAMAN',
                          value: gempa.kedalaman.isNotEmpty
                              ? gempa.kedalaman
                              : '-',
                        ),
                        const SizedBox(width: 10),
                        _buildStatBox(
                          label: 'EPISENTRUM',
                          value:
                              '${alertData.distanceKm.toStringAsFixed(1)} km',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Section Title "Lakukan sekarang"
              const Text(
                'Lakukan sekarang',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 12),

              // 4. Instructions Action Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: List.generate(allInstructions.length, (index) {
                    final isLast = index == allInstructions.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0.0 : 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: secondaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                allInstructions[index],
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Dynamic Context Chips
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: secondaryAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: secondaryAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEvakuasi
                              ? 'Terdeteksi: Zona Risiko Evakuasi'
                              : 'Terdeteksi: Zona Waspada Gempa',
                          style: const TextStyle(
                            color: secondaryAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_box_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Panduan Resmi BMKG & AI',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // 6. Action Buttons
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    foregroundColor: AppColors.white,
                    elevation: 4,
                    shadowColor: primaryAccent.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    if (isMapAvailable) {
                      context.push('/map');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Peta tidak tersedia! Harap ikuti instruksi AI di atas.',
                          ),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BUKA PETA EVAKUASI',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              // Tombol "Lihat panduan lengkap" sengaja dihapus: halaman ini
              // sudah jadi panduan lengkapnya, dan tombol back di AppBar
              // sudah menuju ke tempat yang sama (context.go('/')).
              if (!hasInternet) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.textHint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lastEwsCheck != null
                          ? 'Tampil tanpa internet · diambil sejak ${_formatHm(lastEwsCheck)}'
                          : 'Tampil tanpa internet · data tersimpan di perangkat',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHm(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildStatBox({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
