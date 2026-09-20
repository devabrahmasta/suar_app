import 'package:flutter_test/flutter_test.dart';
import 'package:suar_app/features/ews_ai/data/gemini_triage_service.dart';
import 'package:suar_app/features/ews_ai/domain/gempa_model.dart';
import 'package:suar_app/features/user/domain/user_model.dart';

GempaModel _gempa(String potensi) {
  return GempaModel(
    tanggal: '20 Sep 2026',
    jam: '20:35:02 WIB',
    dateTime: '2026-09-20T13:35:02+00:00',
    coordinates: '-7.80,110.36',
    magnitude: '5.2',
    kedalaman: '10 km',
    wilayah: '10 km Tenggara KOTA-YOGYAKARTA',
    potensi: potensi,
    dirasakan: 'III Yogyakarta',
    shakemapUrl: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = UserModel(
    fullName: 'Tester',
    deviceId: 'device-1',
    homeType: 'Rumah',
  );

  group('GeminiTriageService fallback without an API key', () {
    final service = GeminiTriageService(apiKey: '');

    Future<String> statusFor({
      required String potensi,
      required bool isDiZonaMerah,
    }) async {
      final result = await service.analyzeThreat(
        gempa: _gempa(potensi),
        isDiZonaMerah: isDiZonaMerah,
        user: user,
        isAtHome: true,
        speedInMetersPerSecond: 0,
        currentTime: DateTime(2026, 9, 20, 20, 35),
      );
      return result.statusTindakan;
    }

    test('evacuates in a red zone when a tsunami is possible', () async {
      expect(
        await statusFor(potensi: 'Berpotensi tsunami', isDiZonaMerah: true),
        'EVAKUASI',
      );
    });

    test(
      'shelters in place when BMKG says there is no tsunami potential',
      () async {
        expect(
          await statusFor(
            potensi: 'Tidak berpotensi tsunami',
            isDiZonaMerah: true,
          ),
          'BERLINDUNG',
        );
      },
    );

    test('shelters in place outside a red zone', () async {
      expect(
        await statusFor(potensi: 'Berpotensi tsunami', isDiZonaMerah: false),
        'BERLINDUNG',
      );
    });
  });
}
