import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suar_app/features/ews_ai/presentation/ews_provider.dart';
import 'package:suar_app/main.dart';

class SuarBackendService {
  final Dio _dio;
  final SharedPreferences _prefs;
  final String _baseUrl;

  SuarBackendService(this._dio, this._prefs)
      : _baseUrl = dotenv.env['BACKEND_URL'] ?? 'https://lintangnv-suar-backend.hf.space';

  Future<void> registerDevice({
    required String deviceId,
    required String fcmToken,
    String? homeType,
    double? homeLatitude,
    double? homeLongitude,
  }) async {
    try {
      debugPrint('SuarBackendService: Mengirim permintaan registerDevice untuk perangkat: $deviceId');
      final response = await _dio.post(
        '$_baseUrl/users/register-device',
        data: {
          'deviceId': deviceId,
          'fcmToken': fcmToken,
          'homeType': homeType,
          'homeLatitude': homeLatitude,
          'homeLongitude': homeLongitude,
        },
      );
      debugPrint('SuarBackendService: Respons registerDevice status: ${response.statusCode}, data: ${response.data}');
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Gagal registrasi perangkat: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SuarBackendService Error registerDevice: $e');
      rethrow;
    }
  }

  Future<void> updateLocation({
    required String deviceId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('SuarBackendService: Mengirim permintaan updateLocation untuk perangkat: $deviceId ke koordinat: ($latitude, $longitude)');
      final response = await _dio.post(
        '$_baseUrl/users/update-location',
        data: {
          'deviceId': deviceId,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      debugPrint('SuarBackendService: Respons updateLocation status: ${response.statusCode}');
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Gagal memperbarui lokasi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SuarBackendService Error updateLocation: $e');
      rethrow;
    }
  }

  /// Memperbarui lokasi ke backend dengan optimasi jarak (>1 km) dan waktu (>30 menit)
  /// guna menghemat daya baterai perangkat dan mengurangi beban server backend.
  Future<void> updateLocationWithOptimization({
    required String deviceId,
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('SuarBackendService: Memulai pengecekan pembaruan lokasi teroptimasi.');
    final lastLat = _prefs.getDouble('last_sent_latitude');
    final lastLng = _prefs.getDouble('last_sent_longitude');
    final lastTimeString = _prefs.getString('last_sent_time');

    bool shouldUpdate = false;

    if (lastLat == null || lastLng == null || lastTimeString == null) {
      debugPrint('SuarBackendService: Cache lokasi kosong. Perlu dikirim.');
      shouldUpdate = true;
    } else {
      // Hitung pergeseran jarak spasial menggunakan geolocator
      final distanceMeters = Geolocator.distanceBetween(
        lastLat,
        lastLng,
        latitude,
        longitude,
      );

      // Hitung selisih waktu dari pembaruan terakhir
      final lastTime = DateTime.tryParse(lastTimeString) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final minutesElapsed = DateTime.now().difference(lastTime).inMinutes;

      debugPrint('SuarBackendService: Info Optimasi:');
      debugPrint('  - Jarak Pergeseran: ${distanceMeters.toStringAsFixed(2)}m (Threshold: 1000m)');
      debugPrint('  - Selisih Waktu: ${minutesElapsed}menit (Threshold: 30menit)');

      // Threshold: Bergerak >= 1000m (1 km) ATAU Waktu >= 30 menit
      if (distanceMeters >= 1000 || minutesElapsed >= 30) {
        shouldUpdate = true;
      }
    }

    debugPrint('SuarBackendService: Keputusan Pembaruan -> shouldUpdate = $shouldUpdate');

    if (shouldUpdate) {
      await updateLocation(
        deviceId: deviceId,
        latitude: latitude,
        longitude: longitude,
      );

      // Simpan koordinat dan waktu terbaru di cache lokal
      await _prefs.setDouble('last_sent_latitude', latitude);
      await _prefs.setDouble('last_sent_longitude', longitude);
      await _prefs.setString('last_sent_time', DateTime.now().toIso8601String());

      debugPrint('SuarBackendService: Cache koordinat dan waktu terbaru diperbarui.');
    } else {
      debugPrint('SuarBackendService: Pengiriman dilewati untuk efisiensi daya & jaringan.');
    }
  }

  Future<Map<String, dynamic>> simulateAlert({
    required double magnitude,
    required String depth,
    required double latitude,
    required double longitude,
    required String potensi,
    required String wilayah,
  }) async {
    try {
      debugPrint('SuarBackendService: Mengirim permintaan simulasi gempa ke backend: $wilayah');
      final response = await _dio.post(
        '$_baseUrl/alerts/simulate',
        data: {
          'magnitude': magnitude,
          'depth': depth,
          'latitude': latitude,
          'longitude': longitude,
          'potensi': potensi,
          'wilayah': wilayah,
        },
      );
      debugPrint('SuarBackendService: Respons simulasi status: ${response.statusCode}');
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Gagal melakukan simulasi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SuarBackendService Error simulateAlert: $e');
      rethrow;
    }
  }
}

final suarBackendServiceProvider = Provider<SuarBackendService>((ref) {
  return SuarBackendService(
    ref.watch(dioProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

