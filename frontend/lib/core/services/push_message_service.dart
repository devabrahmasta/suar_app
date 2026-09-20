import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:suar_app/core/services/notification_service.dart';

class PushMessageService {
  static const Set<String> _alertTypes = {
    'EARTHQUAKE_ALERT',
    'TSUNAMI_EVACUATION_ALERT',
  };
  static const String _realEwsPayload = 'REAL_EWS';

  static Future<void> init() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && isAlertMessage(initialMessage)) {
      NotificationService.initialPayload ??= _realEwsPayload;
    }
  }

  static bool isAlertMessage(RemoteMessage message) {
    return _alertTypes.contains(message.data['type']);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!isAlertMessage(message)) return;

    final notification = message.notification;
    await NotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: notification?.title ?? '⚠️ PERINGATAN GEMPA BUMI (SUAR)',
      body: notification?.body ?? 'Buka SUAR untuk melihat detail peringatan.',
      payload: _realEwsPayload,
    );
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    if (!isAlertMessage(message)) return;

    NotificationService.selectNotificationStream.add(_realEwsPayload);
  }
}
