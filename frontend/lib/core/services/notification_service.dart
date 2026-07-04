import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
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
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'suar_darurat_v5',
          'Peringatan Darurat',
          channelDescription: 'Notifikasi untuk peringatan gempa & tsunami EWS',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          sound: RawResourceAndroidNotificationSound('chicken_screaming'),
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
