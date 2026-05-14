import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../data/bmkg_service.dart';
import '../data/location_service.dart';
import '../data/inarisk_service.dart';
import '../data/gemini_triage_service.dart';
import '../domain/triage_result_model.dart';
import '../domain/gempa_model.dart';
import 'package:geolocator/geolocator.dart';
import '../../user/presentation/user_notifier.dart';
import '../../../core/services/notification_service.dart';

final dioProvider = Provider<Dio>((ref) => Dio());

final bmkgServiceProvider = Provider<BmkgService>((ref) {
  return BmkgService(ref.watch(dioProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final inariskServiceProvider = Provider<InaRiskService>((ref) {
  return InaRiskService(ref.watch(dioProvider));
});

final geminiTriageServiceProvider = Provider<GeminiTriageService>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  return GeminiTriageService(apiKey: apiKey);
});

final notificationPayloadProvider = StreamProvider<String?>((ref) {
  return NotificationService.selectNotificationStream.stream;
});

class EwsAlertData {
  final TriageResult triageResult;
  final GempaModel gempa;
  final double distanceKm;

  EwsAlertData({
    required this.triageResult,
    required this.gempa,
    required this.distanceKm,
  });
}

class EwsNotifier extends AsyncNotifier<EwsAlertData?> {
  @override
  Future<EwsAlertData?> build() async {
    return null;
  }

  Future<void> checkLatestThreat() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final bmkgService = ref.read(bmkgServiceProvider);
      final gempa = await bmkgService.fetchLatestEarthquake();

      final locService = ref.read(locationServiceProvider);
      final position = await locService.getCurrentPosition();

      final inariskService = ref.read(inariskServiceProvider);
      final isDiZonaMerah = await inariskService.checkTsunamiHazard(
        position.latitude,
        position.longitude,
      );

      final user = ref.read(userProvider);
      if (user == null) throw Exception('Sistem gagal memuat profil pengguna.');

      bool isAtHome = false;
      if (user.homeLatitude != null && user.homeLongitude != null) {
        final distanceToHome = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          user.homeLatitude!,
          user.homeLongitude!,
        );
        isAtHome = distanceToHome <= 100;
      }

      double distanceKm = 0.0;
      try {
        final coords = gempa.coordinates.split(',');
        if (coords.length == 2) {
          final latGempa = double.tryParse(coords[0].trim()) ?? 0.0;
          final lngGempa = double.tryParse(coords[1].trim()) ?? 0.0;
          final distMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            latGempa,
            lngGempa,
          );
          distanceKm = distMeters / 1000;
        }
      } catch (e) {
        print("Gagal menghitung jarak gempa: $e");
      }

      final geminiService = ref.read(geminiTriageServiceProvider);
      final finalResult = await geminiService.analyzeThreat(
        gempa: gempa,
        isDiZonaMerah: isDiZonaMerah,
        user: user,
        isAtHome: isAtHome,
        speedInMetersPerSecond: position.speed,
        currentTime: DateTime.now(),
      );

      return EwsAlertData(
        triageResult: finalResult,
        gempa: gempa,
        distanceKm: distanceKm,
      );
    });
  }

  Future<void> triggerMockThreat({
    required GempaModel dummyGempa,
    required bool dummyIsDiZonaMerah,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final user = ref.read(userProvider);
      if (user == null) throw Exception('Sistem gagal memuat profil pengguna.');

      final geminiService = ref.read(geminiTriageServiceProvider);
      final finalResult = await geminiService.analyzeThreat(
        gempa: dummyGempa,
        isDiZonaMerah: dummyIsDiZonaMerah,
        user: user,
        isAtHome: true,
        speedInMetersPerSecond: 0.0,
        currentTime: DateTime.now(),
      );

      return EwsAlertData(
        triageResult: finalResult,
        gempa: dummyGempa,
        distanceKm: 12.5,
      );
    });
  }
}

final ewsProvider = AsyncNotifierProvider<EwsNotifier, EwsAlertData?>(() {
  return EwsNotifier();
});
