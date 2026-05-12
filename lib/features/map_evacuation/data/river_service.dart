import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RiverService {
  final Dio _dio;

  RiverService(this._dio);

  Future<bool> isNearRiver(LatLng point, {int radius = 50}) async {
    try {
      final query = '''
        [out:json];
        (
          way["waterway"="river"](around:$radius, ${point.latitude}, ${point.longitude});
          way["waterway"="stream"](around:$radius, ${point.latitude}, ${point.longitude});
          way["waterway"="canal"](around:$radius, ${point.latitude}, ${point.longitude});
        );
        out count;
      ''';

      final response = await _dio.post(
        'https://overpass-api.de/api/interpreter',
        data: query,
        options: Options(
          contentType: 'text/plain',
          sendTimeout: const Duration(seconds: 5), 
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200) {
        final elements = response.data['elements'] as List;
        if (elements.isNotEmpty && elements.first['tags'] != null) {
          final waysCount = elements.first['tags']['ways'] ?? '0';
          return int.parse(waysCount.toString()) > 0;
        }
      }
      return false;
    } catch (e) {
      print('⚠️ River API Error: Batal mengecek sungai (dianggap aman) -> $e');
      return false;
    }
  }
}