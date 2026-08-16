import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/gempa_model.dart';
import '../domain/triage_result_model.dart';
import '../../user/domain/user_model.dart';

class GeminiTriageService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiTriageService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: apiKey.isNotEmpty ? apiKey : 'mock_key',
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
    String protocolJson = '';
    try {
      protocolJson = await rootBundle.loadString(
        'assets/json/protokol_mitigasi.json',
      );
    } catch (e) {
      debugPrint('GeminiTriageService: Gagal memuat asset JSON protokol: $e');
    }

    try {
      if (apiKey.isEmpty) {
        throw Exception(
          'GEMINI_API_KEY kosong, menggunakan fallback protokol resmi',
        );
      }

      final String timeFormat =
          "${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}";
      final bool isNight = currentTime.hour >= 22 || currentTime.hour < 5;
      final bool isMovingFast = speedInMetersPerSecond > 5.0;

      final String prompt =
          '''
Anda adalah AI Sistem Peringatan Dini (SUAR) yang ahli dalam manajemen bencana Indonesia.
Tugas Anda adalah memilihkan instruksi keselamatan resmi berdasarkan database protokol berikut ini:

--- DATABASE PROTOKOL MITIGASI RESMI PEMERINTAH (BMKG, BNPB, KemenPUPR) ---
$protocolJson
--------------------------------------------------------------------------

FAKTA 1 (DATA GEMPA BMKG):
- Kekuatan: ${gempa.magnitude} SR
- Kedalaman: ${gempa.kedalaman}
- Lokasi Pusat: ${gempa.wilayah}
- Status Potensi: ${gempa.potensi}

FAKTA 2 (DATA INARISK & LOKASI):
- Apakah pengguna di zona merah tsunami? JAWABAN: ${isDiZonaMerah ? 'YA' : 'TIDAK'}

FAKTA 3 (KONTEKS SITUASIONAL & PROFIL PENGGUNA):
- Nama: ${user.fullName}
- Waktu Lokal: $timeFormat (Malam/Gelap: ${isNight ? 'YA' : 'TIDAK'})
- Kecepatan Gerak: $speedInMetersPerSecond m/s (Sedang Berkendara: ${isMovingFast ? 'YA' : 'TIDAK'})
- Posisi: ${isAtHome ? 'Di Rumah (Tipe: ${user.homeType})' : 'Di Luar Rumah / Jalan / Fasilitas Umum'}
- Kebutuhan Khusus / Kondisi Fisik: ${user.specialNeeds}

ATURAN KEPUTUSAN STATUS TINDAKAN:
- Jika isDiZonaMerah = true DAN potensi tsunami = true -> Status: "EVAKUASI"
- Jika isDiZonaMerah = false ATAU tidak ada potensi tsunami -> Status: "BERLINDUNG"

ATURAN PENGAMBILAN PROTOKOL (MANDATORI):
1. Pilih dan ambil instruksi HANYA dari DATABASE PROTOKOL MITIGASI RESMI di atas. DILARANG MENGARANG instruksi di luar database tersebut.
2. Jika STATUS = "EVAKUASI", utamakan poin dari bagian "tsunami" -> "zona_merah", "berkendara_pesisir", atau "evakuasi_vertikal".
3. Jika STATUS = "BERLINDUNG", utamakan poin dari bagian "gempa_bumi" -> "dalam_ruangan", "di_tempat_tidur", "berkendara", atau "gedung_bertingkat" sesuai profil posisi pengguna.
4. Jika Kebutuhan Khusus / Kondisi Fisik pengguna BUKAN "Tidak Ada" (misal: Pengguna Kursi Roda / Lansia), WAJIB sertakan poin instruksi keselamatan khusus dari bagian "disabilitas_dan_kursi_roda" atau "disabilitas_dan_evakuasi_khusus".

Keluarkan hasil analisis murni DALAM FORMAT JSON SAJA seperti ini (TANPA blok kode markdown ```json):
{
  "status_tindakan": "EVAKUASI" atau "BERLINDUNG",
  "tindakan_segera": ["poin instruksi 1 dari protokol resmi", "poin 2", "poin 3"],
  "persiapan": ["poin persiapan 1 dari protokol resmi", "poin 2"],
  "aktifkan_peta": true / false
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final String responseText = response.text ?? '{}';
      final Map<String, dynamic> jsonMap = jsonDecode(responseText);

      return TriageResult.fromJson(jsonMap);
    } catch (e) {
      debugPrint('GeminiTriageService Fallback ke Protokol Lokal ($e)');
      final bool isTsunami = gempa.potensi.toLowerCase().contains('tsunami');
      final bool daruratKritis = isTsunami && isDiZonaMerah;

      final bool hasSpecialNeeds = user.specialNeeds != 'Tidak Ada';
      final bool isWheelchair = user.specialNeeds.contains('Kursi Roda');

      if (daruratKritis) {
        return TriageResult(
          statusTindakan: 'EVAKUASI',
          tindakanSegera: [
            if (isWheelchair)
              'Bagi pengguna kursi roda: minta bantuan pendamping/warga sekitar untuk evakuasi cepat lewat jalur bidang miring (ramp) atau evakuasi vertikal ke lantai 3+ gedung beton kokoh.',
            if (hasSpecialNeeds && !isWheelchair)
              'Khusus kondisi kebutuhan khusus (${user.specialNeeds}): prioritaskan pendampingan evakuasi cepat ke dataran tinggi atau lantai 3+ gedung kokoh.',
            'Tinggalkan barang bawaan berat. Segera evakuasi ke dataran tinggi atau tempat evakuasi sementara (TES).',
            'Ikuti petunjuk arah rute evakuasi aplikasi SUAR menuju area bebas risiko tsunami.',
          ],
          persiapan: [
            if (hasSpecialNeeds)
              'Siapkan kartu identitas darurat, obat-obatan esensial, dan alat bantu fisik (tongkat/alat bantu dengar).',
            'Jika rute darat terputus, lakukan Evakuasi Vertikal ke lantai 3+ gedung beton kokoh.',
            'Buka menu P3K Dasar pada aplikasi SUAR jika ada yang memerlukan bantuan medis.',
          ],
          aktifkanPeta: true,
        );
      } else {
        return TriageResult(
          statusTindakan: 'BERLINDUNG',
          tindakanSegera: [
            if (isWheelchair)
              'Kunci roda kursi roda segera saat guncangan terjadi, lalu lindungi kepala dan leher dengan bantal, helm, atau kedua tangan.',
            if (hasSpecialNeeds && !isWheelchair)
              'Khusus kondisi (${user.specialNeeds}): ambil posisi berbaring/duduk di samping struktur kokoh dan lindungi kepala.',
            'Jangan lari keluar bangunan saat guncangan masih terjadi. Tunggu hingga guncangan benar-benar reda.',
            'Drop, Cover, Hold On: Merunduk, lindungi kepala dan leher di bawah meja yang kokoh, dan berpegangan erat.',
          ],
          persiapan: [
            'Matikan segera kompor, regulator gas, dan instalasi listrik untuk mencegah bahaya kebakaran.',
            'Jangan gunakan lift. Gunakan tangga darurat saat evakuasi setelah getaran reda.',
          ],
          aktifkanPeta: false,
        );
      }
    }
  }
}
