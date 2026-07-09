import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../domain/gempa_model.dart';

class BmkgService {
  final Dio _dio;

  BmkgService(this._dio);

  Future<GempaModel> fetchLatestEarthquake() async {
    // 1. Coba ambil dari NestJS backend kita terlebih dahulu (data ter-filter dan ter-evaluasi)
    try {
      final String baseUrl = dotenv.env['BACKEND_URL'] ?? 'https://lintangnv-suar-backend.hf.space';
      final response = await _dio.get('$baseUrl/alerts/latest');
      if (response.statusCode == 200 && response.data != null) {
        debugPrint('Backend: Berhasil mengambil data gempa terproses dari cloud.');
        return GempaModel.fromBackendJson(response.data);
      }
    } catch (e) {
      debugPrint('Backend: Gagal mengambil data /alerts/latest ($e). Melakukan fallback langsung ke BMKG...');
    }

    // 2. Fallback langsung ke API BMKG jika backend down/offline
    try {
      const url = 'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        return GempaModel.fromJson(response.data);
      } else {
        throw Exception(
          'Gagal menghubungi server BMKG: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw Exception('Masalah jaringan atau server BMKG down: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan saat memproses data gempa: $e');
    }
  }
}
