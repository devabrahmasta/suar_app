# 🚨 Dokumentasi & Rangkuman Sistem EWS (Early Warning System) SUAR

Dokumen ini merangkum seluruh perubahan, komponen baru, serta arsitektur yang telah dibangun pada modul **Early Warning System (EWS)** aplikasi SUAR, baik di sisi **Cloud Backend (NestJS + PostGIS)** maupun **Mobile Frontend (Flutter + Riverpod)**.

---

## 🏗️ Ringkasan Komponen yang Dibuat & Diubah

Berikut adalah peta perubahan komponen EWS pada monorepo proyek SUAR:

### 1. Sisi Cloud Backend (NestJS)
* **[main.ts](./backend/src/main.ts):** Memprioritaskan DNS resolve ke IPv4 secara global guna menghindari kegagalan koneksi IPv6 (`ENETUNREACH`) pada platform hosting cloud (seperti Hugging Face Spaces).
* **[alerts.service.ts](./backend/src/alerts/alerts.service.ts):**
  * Modul Polling terjadwal (`Cron`) untuk memantau API BMKG secara real-time.
  * Logika de-duplikasi data gempa untuk mencegah peringatan ganda (redundant).
  * Perhitungan radius dampak dinamis berbasis magnitudo dan potensi tsunami.
  * Kueri geospasial menggunakan PostGIS (`ST_DWithin`) untuk memfilter perangkat pengguna yang masuk radius bahaya.
  * Endpoint baru `GET /alerts/latest` untuk menyajikan data gempa terbersih terakhir kepada frontend.
* **[alerts.controller.ts](./backend/src/alerts/alerts.controller.ts):** Menyediakan REST API endpoint `POST /alerts/trigger-poll` (pemicu manual untuk simulasi) dan `GET /alerts/latest` (pengambilan data gempa teraktif).
* **[users.service.ts](./backend/src/users/users.service.ts) & [users.controller.ts](./backend/src/users/users.controller.ts):** Manajemen koordinat lokasi perangkat (`lastLocation`) menggunakan tipe data spasial `Geometry(Point, 4326)` di database PostgreSQL/PostGIS.

### 2. Sisi Mobile Frontend (Flutter)
* **[suar_backend_service.dart](./frontend/lib/core/services/suar_backend_service.dart) [NEW]:** Penghubung REST API ke cloud backend dengan optimasi kompresi data spasial.
* **[bmkg_service.dart](./frontend/lib/features/ews_ai/data/bmkg_service.dart):** Logika **Hybrid Fallback** yang mengutamakan pengambilan data gempa dari cloud backend kita (`/alerts/latest`), namun secara otomatis beralih langsung ke API BMKG asli (`autogempa.json`) jika koneksi internet terputus atau backend luring.
* **[ews_provider.dart](./frontend/lib/features/ews_ai/presentation/ews_provider.dart):** Menghubungkan pembacaan GPS geolocator, pengecekan InaRISK, pemfilteran signifikansi ancaman gempa, dan pemanggilan analisis AI Triage (Google Gemini).
* **[user_notifier.dart](./frontend/lib/features/user/presentation/user_notifier.dart):** Otomatisasi pendaftaran token perangkat fisik ke backend pada saat pembuatan profil dan startup aplikasi.

---

## 🔍 Logika & Metode Filter Gempa EWS (Detail)

Untuk mencegah terjadinya **Alert Fatigue** (kejenuhan notifikasi) pada pengguna serta menghindari kelebihan beban komputasi server, SUAR menerapkan metode **Penyaringan Dua Lapis (Dual-Layer Filtering)**:

```
+-------------------------------------------------------------+
|                     1. DATA GEMPA BMKG                      |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|            LAPIS 1: SERVER-SIDE SPATIAL FILTER              |
|        - Deteksi Tsunami / Magnitudo >= 5.0                 |
|        - Hitung Radius Dampak Dinamis (50km s.d 250km)      |
|        - PostGIS ST_DWithin (Kueri Spasial Database)         |
+-------------------------------------------------------------+
                              |
                  (Hanya dikirim ke user terdampak)
                              v
+-------------------------------------------------------------+
|            LAPIS 2: CLIENT-SIDE PROXIMITY FILTER            |
|  Filter sensitivitas jarak vs kekuatan gempa luring:        |
|  - Tsunami / Mag >= 7.0  --> Semua Jarak                     |
|  - Mag >= 6.0            --> Radius Jarak <= 1.000 KM       |
|  - Mag >= 5.0            --> Radius Jarak <= 500 KM         |
+-------------------------------------------------------------+
                              |
                    (Lolos Filter Signifikan)
                              v
+-------------------------------------------------------------+
|              TRIGGER AI TRIAGE (GEMINI FLASH)               |
|            & NOTIFIKASI SUARA ALARM DARURAT                 |
+-------------------------------------------------------------+
```

---

### Lapis 1: Penyaringan Spasial Dinamis di Sisi Server (Server-Side)

Saat backend berhasil mem-polling data gempa baru dari BMKG, backend akan mengevaluasi gempa tersebut dengan langkah-langkah berikut:

#### A. Filter Ambang Batas Awal (Initial Threshold)
Aplikasi hanya memproses gempa yang berpotensi merusak atau membahayakan keselamatan jiwa:
1. Gempa memiliki **Magnitudo >= 5.0**, ATAU
2. Gempa memiliki **Potensi Tsunami** (medeteksi string `'tsunami'` pada kolom potensi BMKG).

#### B. Perhitungan Radius Dampak Dinamis (Dynamic Impact Radius)
Backend tidak menggunakan radius statis (misal 100km untuk semua gempa), melainkan menentukan radius bahaya berdasarkan kekuatan energi gempa bumi:

| Kondisi Gempa | Radius Dampak Dinamis | Keterangan Bahaya |
| :--- | :--- | :--- |
| **Potensi Tsunami** ATAU **Magnitudo >= 6.5** | **`250 KM`** | Area pesisir pantai dalam radius ini berisiko tinggi tsunami. |
| **Magnitudo >= 6.0** (tapi < 6.5) | **`150 KM`** | Guncangan kuat berpotensi merusak struktur bangunan sipil. |
| **Magnitudo >= 5.5** (tapi < 6.0) | **`100 KM`** | Guncangan sedang berisiko merubuhkan benda gantung/dinding rapuh. |
| **Magnitudo >= 5.0** (tapi < 5.5) | **`50 KM`** | Getaran ringan yang dirasakan jelas di sekitar episentrum. |

#### C. Kueri Geospasial Database (PostGIS `ST_DWithin`)
Setelah radius dampak dinamis ditentukan, backend melakukan pencarian lokasi secara instan menggunakan fungsi indeks geospasial PostgreSQL/PostGIS. 

Kueri SQL yang dijalankan di bawah TypeORM:
```sql
SELECT * FROM user_devices device
WHERE device.fcmToken IS NOT NULL
  AND ST_DWithin(
    device.lastLocation::geography,
    ST_SetSRID(ST_Point(:longitude_gempa, :latitude_gempa), 4326)::geography,
    :radius_dalam_meter
  );
```
* **Metode:** `ST_DWithin` menghitung jarak terpendek di atas permukaan bumi bola (*Spheroid/Geography*) antara koordinat aktif terakhir pengguna (`lastLocation`) dengan titik pusat koordinat gempa (`epicenter`).
* **Hasil:** Hanya perangkat pengguna yang berada di dalam radius bahaya saja yang akan menerima push notification. Pengguna di luar radius tidak akan terganggu oleh alarm darurat.

---

### Lapis 2: Penyaringan Proximitas Luring di Sisi Perangkat (Client-Side)

Karena SUAR berorientasi **Offline-First**, perangkat pengguna harus dapat menyaring ancaman gempa secara mandiri tanpa bantuan server ketika internet terputus (menggunakan koordinat luring ter-cache).

Pada berkas `ews_provider.dart`, fungsi `checkLatestThreat()` melakukan pemfilteran lokal sebelum menyalakan alarm suara dan AI Triage:

1. **Kalkulasi Jarak Mandiri:** Perangkat menghitung jarak astronomis (dalam kilometer) antara posisi GPS real-time satelit HP dengan koordinat episentrum gempa menggunakan formula Haversine (`Geolocator.distanceBetween`).
2. **Aturan Evaluasi Signifikansi:**
   * **Skenario Tsunami & Gempa Sangat Besar (Mag >= 7.0):** Ditandai **Signifikan** untuk seluruh pengguna tanpa batas jarak (mengingat rambatan gelombang tsunami bisa sangat jauh).
   * **Skenario Gempa Besar (Mag >= 6.0):** Ditandai **Signifikan** hanya jika jarak pengguna ke episentrum **<= 1.000 KM**.
   * **Skenario Gempa Sedang (Mag >= 5.0):** Ditandai **Signifikan** hanya jika jarak pengguna ke episentrum **<= 500 KM**.
   * **Gempa di bawah kriteria tersebut:** Diabaikan secara otomatis oleh perangkat guna mencegah alarm palsu.

3. **Eksekusi Akhir:** Jika gempa dinyatakan **Signifikan**, sistem akan:
   - Memutar audio alarm kencang di latar belakang (layanan Foreground Service).
   - Memicu Google Gemini AI Flash untuk menyusun analisis *Triage* (Evakuasi vs. Berlindung di tempat) sesuai profil kerentanan bangunan dan zonasi InaRISK pengguna.

---

## ⚡ Optimasi Sinkronisasi Koordinat GPS Mobile

Untuk menjaga daya baterai handphone pengguna agar tidak boros akibat terus-menerus mengirim request koordinat GPS ke server, kita mengimplementasikan filter displacement dan interval waktu pada [suar_backend_service.dart](./frontend/lib/core/services/suar_backend_service.dart):

```dart
// Threshold: Bergerak >= 1000m (1 km) ATAU Waktu >= 30 menit
if (distanceMeters >= 1000 || minutesElapsed >= 30) {
  shouldUpdate = true; // Kirim ke server
} else {
  shouldUpdate = false; // Lewati request
}
```
Metode ini memastikan server memiliki data geospasial yang akurat untuk mitigasi bencana tanpa membebani perangkat secara berlebihan dalam kondisi sehari-hari.
