import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suar_app/core/services/push_message_service.dart';

void main() {
  group('PushMessageService.isAlertMessage', () {
    bool isAlert(String? type) {
      return PushMessageService.isAlertMessage(
        RemoteMessage(data: {'type': ?type}),
      );
    }

    test('accepts shaking alerts', () {
      expect(isAlert('EARTHQUAKE_ALERT'), isTrue);
    });

    test('accepts tsunami evacuation alerts', () {
      expect(isAlert('TSUNAMI_EVACUATION_ALERT'), isTrue);
    });

    test('ignores other or missing message types', () {
      expect(isAlert('PROMO'), isFalse);
      expect(isAlert(null), isFalse);
    });
  });
}
