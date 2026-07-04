import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/gempa_model.dart';
import '../domain/triage_result_model.dart';
import '../../user/domain/user_model.dart';

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
      final String timeFormat =
          "${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}";
      final bool isNight = currentTime.hour >= 22 || currentTime.hour < 5;
      final bool isMovingFast = speedInMetersPerSecond > 5.0;
      final String prompt =
          '''
Anda adalah AI Sistem Peringatan Dini (SUAR) yang ahli dalam manajemen bencana dan SOP Keselamatan Pemerintah Indonesia (BMKG, BNPB, KemenPUPR).
Tugas Anda adalah memberikan instruksi keselamatan yang SANGAT SINGKAT, TEGAS, dan BERDASARKAN KONTEKS pengguna saat ini.

FAKTA 1 (DATA BMKG):
- Kekuatan: ${gempa.magnitude} SR
- Kedalaman: ${gempa.kedalaman}
- Lokasi Pusat: ${gempa.wilayah}
- Status Potensi: ${gempa.potensi}

FAKTA 2 (DATA INARISK & LOKASI):
- Apakah pengguna di zona merah tsunami? JAWABAN: ${isDiZonaMerah ? 'YA' : 'TIDAK'}

FAKTA 3 (KONTEKS SITUASIONAL & PROFIL):
- Nama: ${user.fullName}
- Waktu Lokal: $timeFormat (Malam/Gelap: ${isNight ? 'YA' : 'TIDAK'})
- Kecepatan Gerak: $speedInMetersPerSecond m/s (Sedang Berkendara: ${isMovingFast ? 'YA' : 'TIDAK'})
- Posisi: ${isAtHome ? 'Di Rumah (Tipe: ${user.homeType})' : 'Di Luar Rumah / Jalan / Fasilitas Umum'}

ATURAN KEPUTUSAN STATUS TINDAKAN:
- Jika isDiZonaMerah = true DAN potensi tsunami = true -> Status: "EVAKUASI"
- Jika isDiZonaMerah = false ATAU tidak ada potensi tsunami -> Status: "BERLINDUNG"

ATURAN INSTRUKSI KESELAMATAN (SOP PEMERINTAH WAJIB DIIKUTI):
Gunakan bahasa Indonesia yang ringkas dan padat agar mudah dibaca saat panik.
Pastikan urutan instruksi sesuai dan berurutan berdasarkan tingkat urgensi dan waktu.

[JIKA STATUS "BERLINDUNG" (GEMPA BUMI)]
- WAJIB sampaikan: "JANGAN LARI KELUAR BANGUNAN SAAT GUNCANGAN MASIH TERJADI. Tunggu hingga guncangan reda."
- Instruksikan: "Drop, Cover, Hold On (Merunduk, Lindungi Kepala, Berpegangan)."
- Jika di dalam ruangan: Berlindung di kolong meja. Jika tidak ada meja, merapat ke pilar utama/sudut bangunan. Jauhi kaca.
- Jika waktu malam/tidur: Tetap di kasur, tengkurap, lindungi kepala/leher dengan bantal.
- Jika di rumah: Ingatkan untuk mematikan kompor/cabut regulator gas untuk mencegah kebakaran.
- Jika sedang berkendara (YA): Segera menepi perlahan, tarik rem tangan, TETAP DI DALAM kendaraan. Hindari jembatan/pohon.

[JIKA STATUS "EVAKUASI" (TSUNAMI)]
- WAJIB sampaikan: "TINGGALKAN BARANG BAWAAN. IKUTI PETA RUTE SUAR KE DATARAN TINGGI."
- WAJIB sampaikan: "Gelombang tsunami bisa datang hingga 5 kali. JANGAN KEMBALI KE BAWAH sebelum ada instruksi resmi."
- Jika sedang berkendara (YA) dan terjebak macet: TINGGALKAN kendaraan dan berjalan kaki ke tempat tinggi.
- Jika di "Apartemen/Rusun" atau "Gedung/Kantor": Gunakan tangga darurat, DILARANG KERAS menggunakan lift. Jika jalan ke bawah terputus, lakukan Evakuasi Vertikal ke atap gedung kokoh.
- Pasca-kejadian: Ingatkan untuk menjauhi genangan air tsunami (bahaya listrik) dan buka menu "P3K Dasar" di aplikasi SUAR jika ada yang terluka.

Keluarkan hasil analisis murni DALAM FORMAT JSON SAJA seperti ini (TANPA blok kode markdown ```json):
{
  "status_tindakan": "EVAKUASI" atau "BERLINDUNG",
  "tindakan_segera": ["tindakan personal 1", "tindakan personal 2", "tindakan 3"],
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
            ? [
                'Amankan keluarga dan bawa dokumen penting.',
                'Pakai alas kaki yang tertutup.',
              ]
            : [
                'Matikan kompor dan cabut gas.',
                'Siapkan senter jika listrik padam.',
              ],
        aktifkanPeta: daruratKritis,
      );
    }
  }
}
