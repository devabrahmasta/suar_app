import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suar_app/core/services/suar_backend_service.dart';

import '../../support/fake_http_adapter.dart';

const _backendHost = 'backend.test';

Future<(SuarBackendService, FakeHttpAdapter)> _build(
  ResponseBody Function(RequestOptions options) respond,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final adapter = FakeHttpAdapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  return (SuarBackendService(dio, prefs), adapter);
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'BACKEND_URL=https://$_backendHost');
  });

  group('SuarBackendService.calculateImpact', () {
    test('posts the location and alert id and parses the estimate', () async {
      final (service, adapter) = await _build(
        (_) => jsonResponse({'estimatedMmi': 5.2, 'shakingLevel': 'MODERATE'}),
      );

      final impact = await service.calculateImpact(
        earthquakeId: 'alert-1',
        latitude: -7.99,
        longitude: 110.29,
      );

      expect(impact?.estimatedMmi, 5.2);
      expect(impact?.shakingLevel, 'MODERATE');
      final request = adapter.requests.single;
      expect(request.path, endsWith('/alerts/calculate-impact'));
      expect(request.data, {
        'earthquakeId': 'alert-1',
        'latitude': -7.99,
        'longitude': 110.29,
      });
    });

    test('returns null when the backend fails', () async {
      final (service, _) = await _build(
        (_) => jsonResponse({'message': 'error'}, 500),
      );

      final impact = await service.calculateImpact(
        earthquakeId: 'alert-1',
        latitude: -7.99,
        longitude: 110.29,
      );

      expect(impact, isNull);
    });

    test('returns null when the response is malformed', () async {
      final (service, _) = await _build(
        (_) => jsonResponse({'unexpected': true}),
      );

      final impact = await service.calculateImpact(
        earthquakeId: 'alert-1',
        latitude: -7.99,
        longitude: 110.29,
      );

      expect(impact, isNull);
    });
  });
}
