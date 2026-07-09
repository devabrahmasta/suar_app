import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:suar_app/core/services/notification_service.dart';
import 'package:suar_app/features/map_evacuation/data/map_cache_service.dart';
import 'package:suar_app/features/map_evacuation/presentation/map_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/gempa_model.dart';
import 'ews_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:suar_app/core/services/suar_backend_service.dart';
import 'package:suar_app/features/user/presentation/user_notifier.dart';

class EwsTestingScreen extends ConsumerWidget {
  const EwsTestingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer: EWS Simulator'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Panel Pengujian Skenario AI',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih skenario di bawah ini untuk menyuapkan data dummy ke sistem Triage AI. Aplikasi akan otomatis kembali ke Beranda setelah tombol ditekan.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          _ScenarioCard(
            title: 'Skenario 1: Tsunami Kritis',
            description:
                'Gempa 8.5 SR, Berpotensi Tsunami, User di Zona Merah. (Ekspektasi: Muncul Pop-up Merah EVAKUASI)',
            icon: Icons.waves,
            color: AppColors.danger,
            onTap: () {
              final dummyGempa = GempaModel(
                tanggal: '17 Mar 2026',
                jam: '20:30:00 WIB',
                dateTime: DateTime.now().toIso8601String(),
                coordinates: '-8.50, 109.00',
                magnitude: '8.5',
                kedalaman: '10 km',
                wilayah: '150 km Barat Daya KAB-PANGANDARAN',
                potensi: 'Berpotensi TSUNAMI untuk diteruskan pada masyarakat',
                dirasakan: 'V-VI Pangandaran, IV Cilacap',
                shakemapUrl: '',
              );

              ref
                  .read(ewsProvider.notifier)
                  .triggerMockThreat(
                    dummyGempa: dummyGempa,
                    dummyIsDiZonaMerah: true,
                  );

              ref.read(evacuationRouteProvider.notifier).findRouteManual();

              NotificationService.showNotification(
                id: 1,
                title: '⚠️ PERINGATAN TSUNAMI (SUAR)',
                body:
                    'Gempa M8.5 terdeteksi. Potensi Tsunami di wilayah Anda! Segera evakuasi.',
                payload: 'DUMMY_NO_ACTION',
              );

              context.pop();
            },
          ),
          const SizedBox(height: 16),

          _ScenarioCard(
            title: 'Skenario 2: Gempa Ringan Darat',
            description:
                'Gempa 5.2 SR, Tidak Berpotensi Tsunami. (Ekspektasi: Muncul Banner Oranye BERLINDUNG di Home)',
            icon: Icons.dashboard_customize,
            color: AppColors.warning,
            onTap: () {
              final dummyGempa = GempaModel(
                tanggal: '17 Mar 2026',
                jam: '10:15:00 WIB',
                dateTime: DateTime.now().toIso8601String(),
                coordinates: '-7.80, 110.36',
                magnitude: '5.2',
                kedalaman: '80 km',
                wilayah: '10 km Tenggara KOTA-YOGYAKARTA',
                potensi: 'Tidak berpotensi tsunami',
                dirasakan: 'III Yogyakarta',
                shakemapUrl: '',
              );

              ref
                  .read(ewsProvider.notifier)
                  .triggerMockThreat(
                    dummyGempa: dummyGempa,
                    dummyIsDiZonaMerah: false,
                  );

              NotificationService.showNotification(
                id: 2,
                title: '⚠️ PERINGATAN GEMPA BUMI',
                body:
                    'Gempa M5.2 terdeteksi. Segera berlindung di tempat aman.',
                payload: 'DUMMY_NO_ACTION',
              );

              context.pop();
            },
          ),
          const SizedBox(height: 16),

          _ScenarioCard(
            title: 'Skenario 3: Masuk Zona Merah',
            description:
                'GPS mendeteksi Anda masuk ke zona rawan tsunami saat cuaca aman. (Ekspektasi: Peta offline mulai diunduh otomatis di background)',
            icon: Icons.download_for_offline,
            color: AppColors.info,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final container = ProviderScope.containerOf(context);

              messenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Simulasi: Memasuki Zona Merah. Mengunduh peta radius 3KM...',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.info,
                  duration: Duration(seconds: 4),
                ),
              );

              context.pop();

              try {
                final locService = container.read(locationServiceProvider);
                final position = await locService.getCurrentPosition();
                final centerPoint = LatLng(
                  position.latitude,
                  position.longitude,
                );

                final cacheService = MapCacheService();
                final smartEvacuation = container.read(smartEvacuationProvider);

                List<LatLng>? route;
                try {
                  route = await smartEvacuation.findOptimalRoute(centerPoint);
                  await cacheService.saveOfflineRoute(route);
                } catch (e) {
                  debugPrint('Mode Evakuasi Vertikal: $e');
                }

                if (route != null && route.isNotEmpty) {
                  final allPoints = [centerPoint, ...route];
                  final bounds = LatLngBounds.fromPoints(allPoints);

                  const distance = Distance();
                  final sw = distance.offset(bounds.southWest, 1000, 225);
                  final ne = distance.offset(bounds.northEast, 1000, 45);
                  final paddedBounds = LatLngBounds(sw, ne);

                  await cacheService.downloadMapBoundingBox(paddedBounds);
                } else {
                  await cacheService.downloadMapRadius(
                    centerPoint,
                    radiusInMeters: 3000,
                  );
                }

                messenger.showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.white),
                        SizedBox(width: 12),
                        Text('Peta Offline 3KM Siap Digunakan!'),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 5),
                  ),
                );
                container.invalidate(mapCacheStatusProvider);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Gagal menyimpan peta: $e'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 16),

          _ScenarioCard(
            title: 'Skenario 4: Push Notification Darurat',
            description:
                'Klik ini lalu minimize/tutup aplikasi. Dalam 15 detik, HP Anda akan menerima peringatan darurat. (Ekspektasi: Saat notif diklik, aplikasi terbuka, pop-up Tsunami muncul, dan peta terunduh otomatis)',
            icon: Icons.notification_important,
            color: AppColors.primary,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Peringatan disetel! Silakan minimize aplikasi atau matikan layar HP Anda sekarang.',
                  ),
                  backgroundColor: AppColors.info,
                  duration: Duration(seconds: 5),
                ),
              );

              context.pop();

              Future.delayed(const Duration(seconds: 15), () {
                NotificationService.showNotification(
                  id: 999,
                  title: '⚠️ PERINGATAN TSUNAMI (SUAR)',
                  body:
                      'Gempa M8.5 terdeteksi. Potensi Tsunami di wilayah Anda! Tekan untuk instruksi evakuasi segera.',
                  payload: 'MOCK_TSUNAMI',
                );
              });
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Pengujian Integrasi Cloud Backend (NestJS)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gunakan opsi di bawah ini untuk berinteraksi langsung dengan API backend yang telah dideploy di Hugging Face Spaces.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          _ScenarioCard(
            title: 'Skenario 5: Trigger Polling Real-Time',
            description:
                'Memaksa backend NestJS untuk melakukan polling ke BMKG secara instan via API POST /alerts/trigger-poll. (Ekspektasi: Koneksi sukses & database terupdate)',
            icon: Icons.sync,
            color: Colors.teal,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final dio = ref.read(dioProvider);
              final baseUrl = dotenv.env['BACKEND_URL'] ?? 'https://lintangnv-suar-backend.hf.space';

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Mengirim sinyal pemicu polling ke backend...'),
                  backgroundColor: AppColors.info,
                ),
              );
              context.pop();

              try {
                final response = await dio.post('$baseUrl/alerts/trigger-poll');
                if (response.statusCode == 201 || response.statusCode == 200) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Berhasil memicu polling BMKG di backend!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  throw Exception('Respons status: ${response.statusCode}');
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Gagal memicu polling backend: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),

          _ScenarioCard(
            title: 'Skenario 6: Paksa Kirim GPS ke Backend',
            description:
                'Mengambil GPS HP dan langsung mengirimkannya ke PostgreSQL/PostGIS backend, melewati filter optimasi jarak. (Ekspektasi: Koordinat masuk ke database Supabase seketika)',
            icon: Icons.my_location,
            color: Colors.deepPurple,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final user = ref.read(userProvider);
              final locService = ref.read(locationServiceProvider);
              final backendService = ref.read(suarBackendServiceProvider);

              if (user == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Gagal: Profil pengguna lokal kosong.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                context.pop();
                return;
              }

              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Membaca GPS dan memaksakan pengiriman ke backend...'),
                  backgroundColor: AppColors.info,
                ),
              );
              context.pop();

              try {
                final position = await locService.getCurrentPosition();
                await backendService.updateLocation(
                  deviceId: user.deviceId,
                  latitude: position.latitude,
                  longitude: position.longitude,
                );

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Sukses sinkronisasi koordinat: (${position.latitude}, ${position.longitude})'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Gagal sinkronisasi GPS ke backend: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: AppColors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.play_arrow, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
