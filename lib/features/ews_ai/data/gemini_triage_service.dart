import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/gempa_model.dart';
import '../domain/triage_result_model.dart';
import '../../user/domain/user_model.dart'

class GeminiTriageService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiTriageService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  Future<TriageResult> analyzeThreat({
    required GempaModel gempa,
    required bool isDiZonaMerah,
    required UserModel user,
    required bool isAtHome,
    required double speedInMetersPerSecond,
    required DateTime currentTime,
  }) async {
    try {
      final String timeFormat = "${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}";
      final bool isNight = currentTime.hour >= 22 || currentTime.hour < 5;
      final bool isMovingFast = speedInMetersPerSecond > 5.0;
      final String prompt = '''
Anda adalah AI Sistem Peringatan Dini (EWS) pada aplikasi evakuasi darurat SUAR di Indonesia.
Berikan instruksi keselamatan yang sangat personal, situasional, dan menenangkan.

FAKTA 1 (DATA BMKG):
- Kekuatan: ${gempa.magnitude} SR
- Kedalaman: ${gempa.kedalaman}
- Lokasi Pusat: ${gempa.wilayah}
- Status: ${gempa.potensi}

FAKTA 2 (DATA INARISK & LOKASI):
- Apakah pengguna di zona merah tsunami? JAWABAN: ${isDiZonaMerah ? 'YA' : 'TIDAK'}

FAKTA 3 (KONTEKS SITUASIONAL & PROFIL):
- Nama: ${user.fullName}
- Disabilitas Fisik: ${user.hasDisability ? 'YA' : 'TIDAK'}
- Membawa Balita/Lansia: ${user.hasDependents ? 'YA' : 'TIDAK'}
- Waktu Lokal: $timeFormat (Malam/Gelap: ${isNight ? 'YA' : 'TIDAK'})
- Sedang Berkendara: ${isMovingFast ? 'YA' : 'TIDAK'}
- Posisi: ${isAtHome ? 'Di Rumah (Tipe: ${user.homeType})' : 'Di Luar Rumah / Jalan / Fasilitas Umum'}

ATURAN TRIASE KHUSUS:
1. Panggil nama pengguna (Contoh: "${user.fullName}, tetap tenang!").
2. Jika berpotensi Tsunami DAN di zona merah -> "EVAKUASI". Jika tidak -> "BERLINDUNG".
3. JIKA Sedang Berkendara (YA): Larang keras menyetir. Suruh menepi (jauhi jembatan/pohon), tinggalkan kendaraan jika tsunami, dan lari.
4. JIKA Malam/Gelap (YA): Ingatkan potensi mati listrik, suruh raih senter/HP, waspada pecahan kaca, bangunkan keluarga. JANGAN nyalakan korek api (potensi gas).
5. JIKA Posisi Di Rumah (YA) dan Tipe "Apartemen/Rusun": Dilarang keras menggunakan lift, gunakan tangga darurat.
6. JIKA Posisi Di Luar Rumah (TIDAK) dan Punya Balita/Lansia (YA): Beritahu untuk JANGAN mencoba menerobos rute bahaya untuk pulang menjemput mereka. Prioritaskan keselamatan diri di lokasi saat ini.
7. JIKA Disabilitas Fisik (YA): Sarankan untuk mencari titik aman ramah disabilitas atau minta bantuan warga terdekat menggunakan fitur obrolan Mesh SUAR.
8. Gunakan bahasa Indonesia yang ringkas (maks 3-4 instruksi) agar mudah dibaca saat panik.

Keluarkan hasil analisis DALAM FORMAT JSON SEPERTI INI:
{
  "status_tindakan": "EVAKUASI / BERLINDUNG",
  "tindakan_segera": ["tindakan personal 1", "tindakan personal 2"],
  "persiapan": ["persiapan situasional 1", "persiapan 2"],
  "aktifkan_peta": true / false
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final String responseText = response.text ?? '{}';
      final Map<String, dynamic> jsonMap = jsonDecode(responseText);

      return TriageResult.fromJson(jsonMap);
    } catch (e) {
      final bool daruratKritis =
          gempa.potensi.toLowerCase().contains('tsunami') && isDiZonaMerah;

      return TriageResult(
        statusTindakan: daruratKritis ? 'EVAKUASI' : 'BERLINDUNG',
        tindakanSegera: daruratKritis
            ? [
                'Segera berlari ke dataran tinggi.',
                'Jauhi area pantai dan sungai.',
              ]
            : [
                'Berlindung di bawah meja yang kuat.',
                'Jauhi kaca dan benda yang mudah jatuh.',
              ],
        persiapan: daruratKritis
            ? ['Amankan keluarga dan bawa dokumen penting.', 'Pakai alas kaki yang tertutup.']
            : [
                'Matikan kompor dan cabut gas.',
                'Siapkan senter jika listrik padam.',
              ],
        aktifkanPeta: daruratKritis,
      );
    }
  }
}
