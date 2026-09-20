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

  group('SuarBackendService.fetchNearbyShelters', () {
    final shelterJson = {
      'id': 'shelter-1',
      'name': 'Titik Evakuasi TPA (TPA-01)',
      'type': 'TPA',
      'location': {
        'type': 'Point',
        'coordinates': [110.29, -7.99],
      },
    };

    test('requests an integer radius and parses the shelters', () async {
      final (service, adapter) = await _build(
        (_) => jsonResponse([shelterJson]),
      );

      final shelters = await service.fetchNearbyShelters(
        latitude: -7.99,
        longitude: 110.29,
      );

      expect(shelters.single.id, 'shelter-1');
      expect(shelters.single.position.latitude, -7.99);
      expect(shelters.single.position.longitude, 110.29);
      expect(adapter.requests.single.queryParameters, {
        'latitude': -7.99,
        'longitude': 110.29,
        'radiusInKm': 15,
      });
    });

    test('serves the last successful result when the backend fails', () async {
      var backendDown = false;
      final (service, _) = await _build(
        (_) => backendDown
            ? jsonResponse({'message': 'error'}, 500)
            : jsonResponse([shelterJson]),
      );

      await service.fetchNearbyShelters(latitude: -7.99, longitude: 110.29);
      backendDown = true;
      final shelters = await service.fetchNearbyShelters(
        latitude: -7.99,
        longitude: 110.29,
      );

      expect(shelters.single.id, 'shelter-1');
    });

    test(
      'returns an empty list when the backend fails and nothing is cached',
      () async {
        final (service, _) = await _build(
          (_) => jsonResponse({'message': 'error'}, 500),
        );

        final shelters = await service.fetchNearbyShelters(
          latitude: -7.99,
          longitude: 110.29,
        );

        expect(shelters, isEmpty);
      },
    );
  });
}
