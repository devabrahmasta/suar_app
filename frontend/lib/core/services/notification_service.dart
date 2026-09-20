import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const String _emergencyChannelId = 'suar_darurat_v5';
  static const String _emergencyChannelName = 'Peringatan Darurat';
  static const String _emergencyChannelDescription =
      'Notifikasi untuk peringatan gempa & tsunami EWS';
  static const RawResourceAndroidNotificationSound _emergencySound =
      RawResourceAndroidNotificationSound('chicken_screaming');

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  static String? initialPayload;

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      initialPayload =
          notificationAppLaunchDetails?.notificationResponse?.payload;
    }

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        selectNotificationStream.add(response.payload);
      },
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _emergencyChannelId,
            _emergencyChannelName,
            description: _emergencyChannelDescription,
            importance: Importance.max,
            sound: _emergencySound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _emergencyChannelId,
          _emergencyChannelName,
          channelDescription: _emergencyChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          sound: _emergencySound,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }
}
