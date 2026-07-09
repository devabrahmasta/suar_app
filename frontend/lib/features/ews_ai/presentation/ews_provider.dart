import 'package:flutter/foundation.dart';
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
import '../../../core/services/suar_backend_service.dart';

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

      final user = ref.read(userProvider);
      if (user == null) throw Exception('Sistem gagal memuat profil pengguna.');

      double currentLat = 0.0;
      double currentLng = 0.0;
      double currentSpeed = 0.0;
      bool hasLocation = false;

      try {
        final locService = ref.read(locationServiceProvider);
        final position = await locService.getCurrentPosition();
        currentLat = position.latitude;
        currentLng = position.longitude;
        currentSpeed = position.speed;
        hasLocation = true;

        // Kirim pembaruan lokasi secara teroptimasi ke backend
        final backendService = ref.read(suarBackendServiceProvider);
        await backendService.updateLocationWithOptimization(
          deviceId: user.deviceId,
          latitude: currentLat,
          longitude: currentLng,
        );
      } catch (e) {
        if (user.homeLatitude != null && user.homeLongitude != null) {
          currentLat = user.homeLatitude!;
          currentLng = user.homeLongitude!;
          hasLocation = true;
        }
      }

      bool isDiZonaMerah = false;
      if (hasLocation) {
        final inariskService = ref.read(inariskServiceProvider);
        try {
          isDiZonaMerah = await inariskService.checkTsunamiHazard(
            currentLat,
            currentLng,
          );
        } catch (_) {}
      }

      bool isAtHome = false;
      if (hasLocation &&
          user.homeLatitude != null &&
          user.homeLongitude != null) {
        final distanceToHome = Geolocator.distanceBetween(
          currentLat,
          currentLng,
          user.homeLatitude!,
          user.homeLongitude!,
        );
        isAtHome = distanceToHome <= 100;
      }

      double distanceKm = 0.0;
      if (hasLocation) {
        try {
          final coords = gempa.coordinates.split(',');
          if (coords.length == 2) {
            final latGempa = double.tryParse(coords[0].trim()) ?? 0.0;
            final lngGempa = double.tryParse(coords[1].trim()) ?? 0.0;
            final distMeters = Geolocator.distanceBetween(
              currentLat,
              currentLng,
              latGempa,
              lngGempa,
            );
            distanceKm = distMeters / 1000;
          }
        } catch (e) {
          debugPrint("Gagal menghitung jarak gempa: $e");
        }
      }

      final mag = double.tryParse(gempa.magnitude) ?? 0.0;
      final isTsunami = gempa.potensi.toLowerCase().contains('tsunami');

      bool isSignificant = false;
      if (isTsunami || mag >= 7.0) {
        isSignificant = true;
      } else if (mag >= 6.0 && distanceKm <= 1000) {
        isSignificant = true;
      } else if (mag >= 5.0 && distanceKm <= 500) {
        isSignificant = true;
      }

      if (!isSignificant) {
        return null;
      }

      final geminiService = ref.read(geminiTriageServiceProvider);
      final finalResult = await geminiService.analyzeThreat(
        gempa: gempa,
        isDiZonaMerah: isDiZonaMerah,
        user: user,
        isAtHome: isAtHome,
        speedInMetersPerSecond: currentSpeed,
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
