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
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Gagal registrasi perangkat: ${response.statusCode}');
      }
      debugPrint('Backend: Perangkat $deviceId berhasil didaftarkan.');
    } catch (e) {
      debugPrint('Backend Error registerDevice: $e');
      rethrow;
    }
  }

  Future<void> updateLocation({
    required String deviceId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/users/update-location',
        data: {
          'deviceId': deviceId,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Gagal memperbarui lokasi: ${response.statusCode}');
      }
      debugPrint('Backend: Lokasi perangkat $deviceId diperbarui ke ($latitude, $longitude).');
    } catch (e) {
      debugPrint('Backend Error updateLocation: $e');
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
    final lastLat = _prefs.getDouble('last_sent_latitude');
    final lastLng = _prefs.getDouble('last_sent_longitude');
    final lastTimeString = _prefs.getString('last_sent_time');

    bool shouldUpdate = false;

    if (lastLat == null || lastLng == null || lastTimeString == null) {
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

      // Threshold: Bergerak >= 1000m (1 km) ATAU Waktu >= 30 menit
      if (distanceMeters >= 1000 || minutesElapsed >= 30) {
        shouldUpdate = true;
      }
    }

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

      debugPrint('Backend: Sinkronisasi lokasi teroptimasi berhasil terkirim.');
    } else {
      debugPrint('Backend: Sinkronisasi lokasi dilewati (jarak < 1km & jeda < 30 mnt).');
    }
  }
}

final suarBackendServiceProvider = Provider<SuarBackendService>((ref) {
  return SuarBackendService(
    ref.watch(dioProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
