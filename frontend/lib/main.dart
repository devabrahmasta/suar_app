import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:suar_app/core/services/notification_service.dart';
import 'package:suar_app/core/services/background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/widgets/network_status_chip.dart';
import 'features/ews_ai/presentation/ews_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

bool isFirebaseInitialized = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Firebase: Menerima background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase secara aman (tidak crash jika google-services.json belum di-setup)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    isFirebaseInitialized = true;
    debugPrint('Firebase: Inisialisasi SDK berhasil.');
  } catch (e) {
    debugPrint(
      'Firebase: Gagal inisialisasi (belum dikonfigurasi). Mode mock fallback aktif: $e',
    );
  }

  await NotificationService.init();
  await BackgroundService.init();

  HttpOverrides.global = MyHttpOverrides();

  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();

  await FMTCObjectBoxBackend().initialise();

  final store = FMTCStore('evacuation_map');
  await store.manage.create();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    // Listener notifikasi didaftarkan di root (bukan di HomeScreen) supaya
    // tap notifikasi (cold-start maupun warm-resume) selalu tertangani dari
    // kondisi/halaman apapun yang sedang aktif.
    ref.listen<AsyncValue<String?>>(notificationPayloadProvider, (
      previous,
      next,
    ) {
      if (next.hasValue && next.value != null) {
        _handleNotificationPayload(ref, router, next.value!);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (NotificationService.initialPayload != null) {
        final payload = NotificationService.initialPayload!;
        NotificationService.initialPayload = null;
        _handleNotificationPayload(ref, router, payload);
      }
    });

    return MaterialApp.router(
      title: 'SUAR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            const NetworkStatusChip(),
          ],
        );
      },
    );
  }

  /// Menangani payload notifikasi yang di-tap user, dari kondisi apapun.
  ///
  /// Dipanggil dengan [WidgetRef]+[GoRouter] langsung (bukan lewat
  /// BuildContext bertingkat Router) karena widget ini berada di ATAS
  /// MaterialApp.router, sehingga context di sini belum punya ancestor
  /// GoRouter untuk dipakai context.go()/context.push().
  Future<void> _handleNotificationPayload(
    WidgetRef ref,
    GoRouter router,
    String payload,
  ) async {
    if (payload == 'MOCK_ALERT') {
      // Jalur simulasi (EWS Testing Screen, Skenario 1/2): data alert
      // SUDAH ditrigger & hidup di ewsProvider sebelum notifikasi ini
      // muncul -- aplikasi cuma di-minimize (FlutterAppMinimizerPlus),
      // bukan di-kill, jadi state-nya tetap ada di memori. Jangan
      // trigger ulang / timpa dengan data hardcoded di sini, cukup baca
      // state yang sudah ada lalu jatuh ke pengecekan di bawah.
    } else if (payload == 'REAL_EWS' || payload == 'EWS_ALERT') {
      // Jalur produksi: notifikasi asli dari backend -> fetch ulang.
      await ref.read(ewsProvider.notifier).checkLatestThreat();
    } else {
      router.go('/');
      return;
    }

    // Navigasi ke halaman alert HANYA kalau data alert-nya benar-benar ada
    // (mis. checkLatestThreat() bisa saja menyimpulkan ancaman tidak
    // signifikan dan meninggalkan state null) -> fallback ke Home.
    final alertData = ref.read(ewsProvider).value;
    if (alertData != null) {
      router.push('/alert');
    } else {
      router.go('/');
    }
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
