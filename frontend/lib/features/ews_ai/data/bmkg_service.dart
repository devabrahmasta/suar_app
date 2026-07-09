import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../domain/gempa_model.dart';

class BmkgService {
  final Dio _dio;

  BmkgService(this._dio);

  Future<GempaModel> fetchLatestEarthquake() async {
    debugPrint('BmkgService: Memulai pengambilan data gempa bumi terbaru...');
    // 1. Coba ambil dari NestJS backend kita terlebih dahulu (data ter-filter dan ter-evaluasi)
    try {
      final String baseUrl = dotenv.env['BACKEND_URL'] ?? 'https://lintangnv-suar-backend.hf.space';
      debugPrint('BmkgService: Mencoba mengambil dari NestJS cloud backend: $baseUrl/alerts/latest');
      final response = await _dio.get('$baseUrl/alerts/latest');
      if (response.statusCode == 200 && response.data != null) {
        debugPrint('BmkgService: Kueri ke NestJS cloud backend berhasil.');
        final gempa = GempaModel.fromBackendJson(response.data);
        debugPrint('BmkgService: Data gempa cloud ter-parse -> Wilayah: ${gempa.wilayah}, Mag: ${gempa.magnitude}');
        return gempa;
      }
      debugPrint('BmkgService: Cloud backend merespons tapi data null atau status bukan 200.');
    } catch (e) {
      debugPrint('BmkgService: Kueri ke NestJS cloud backend gagal ($e). Beralih ke fallback langsung BMKG...');
    }

    // 2. Fallback langsung ke API BMKG jika backend down/offline
    try {
      const url = 'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json';
      debugPrint('BmkgService: Melakukan koneksi langsung ke API BMKG: $url');
      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        debugPrint('BmkgService: Koneksi langsung ke BMKG sukses.');
        final gempa = GempaModel.fromJson(response.data);
        debugPrint('BmkgService: Data gempa BMKG ter-parse -> Wilayah: ${gempa.wilayah}, Mag: ${gempa.magnitude}');
        return gempa;
      } else {
        throw Exception(
          'Gagal menghubungi server BMKG: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('BmkgService Error Dio: $e');
      throw Exception('Masalah jaringan atau server BMKG down: ${e.message}');
    } catch (e) {
      debugPrint('BmkgService Error Parsing: $e');
      throw Exception('Terjadi kesalahan saat memproses data gempa: $e');
    }
  }
}
