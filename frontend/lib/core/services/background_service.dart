import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:suar_app/features/ews_ai/data/bmkg_service.dart';
import 'package:suar_app/core/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio();
      final bmkgService = BmkgService(dio);

      final latestGempa = await bmkgService.fetchLatestEarthquake();

      final lastGempaTime = prefs.getString('last_gempa_time_bg');

      if (lastGempaTime != latestGempa.dateTime) {
        await prefs.setString('last_gempa_time_bg', latestGempa.dateTime);

        bool isDanger = false;
        final mag = double.tryParse(latestGempa.magnitude) ?? 0.0;
        final isTsunami = latestGempa.potensi.toLowerCase().contains('tsunami');

        if (isTsunami || mag >= 7.0) {
          isDanger = true;
        } else if (mag >= 5.0) {
          try {
            final position = await Geolocator.getLastKnownPosition();
            if (position != null) {
              final coords = latestGempa.coordinates.split(',');
              final latGempa = double.tryParse(coords[0].trim()) ?? 0.0;
              final lngGempa = double.tryParse(coords[1].trim()) ?? 0.0;

              final distMeters = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                latGempa,
                lngGempa,
              );
              final distKm = distMeters / 1000;

              if (mag >= 6.0 && distKm <= 1000) {
                isDanger = true;
              } else if (mag >= 5.0 && distKm <= 500) {
                isDanger = true;
              }
            } else {
              isDanger = true;
            }
          } catch (e) {
            isDanger = true;
          }
        }

        if (isDanger) {
          await NotificationService.init();
          await NotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: '⚠️ PERINGATAN BAHAYA (SUAR)',
            body:
                'Gempa M${latestGempa.magnitude} di ${latestGempa.wilayah}. ${latestGempa.potensi}',
            payload: 'EWS_ALERT',
          );
        }
      }
      return Future.value(true);
    } catch (e) {
      debugPrint("Background task error: $e");
      return Future.value(true);
    }
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      "suar_ews_background_check_1",
      "ewsBackgroundCheck",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
