# 📜 Kontrak API SUAR Backend

**Versi:** 1.1.0
**Disinkronkan dengan kode:** 20 September 2026, `main` pada commit `10e93e2` (menggantikan v1.0.0, Maret 2026)
**Penyusun:** Backend Lead
**Pembaca:** Tim Mobile Frontend (Flutter)

> [!IMPORTANT]
> Versi 1.0.0 menjanjikan *envelope* respons standar, header `X-Device-ID`/`X-App-Version`, dan beberapa skema respons yang **tidak pernah diimplementasikan**, serta memuat endpoint tsunami yang kini sudah dihapus. Dokumen ini hanya memuat perilaku yang ada di kode. Rujukan utama: `src/**/*.controller.ts`, `src/**/*.service.ts`, dan Swagger UI di `/api/docs`.

---

## 1. Ringkasan

| Modul | Method & Path | Fungsi |
| :--- | :--- | :--- |
| Devices | `POST /devices/register` (alias `/users/register-device`) | Daftar/perbarui token FCM dan lokasi rumah |
| Devices | `POST /devices/location` (alias `/users/update-location`) | Perbarui lokasi aktif, Vs30, dan status zona merah |
| Alerts | `GET /alerts/latest` | Gempa terbaru yang tersimpan |
| Alerts | `POST /alerts/calculate-impact` | Estimasi jarak dan MMI di lokasi pengguna |
| Alerts | `POST /alerts/trigger-poll` | Pemicu polling BMKG manual (dev) |
| Alerts | `POST /alerts/simulate` | Simulasi gempa (dev/QA) |
| Shelters | `GET /shelters` | Semua titik evakuasi |
| Shelters | `GET /shelters/nearby` | Titik evakuasi aktif terdekat |
| Shelters | `POST /shelters` | Daftarkan titik evakuasi |
| Shelters | `PATCH /shelters/:id/evacuees` | Perbarui jumlah pengungsi |
| Shelters | `POST /shelters/seed` | Isi data awal titik evakuasi Bantul |

Endpoint pengecekan zona merah (`/alerts/tsunami-check`) dan ubin overlay (`/alerts/tsunami-tile/...`) **sudah dihapus**. Status zona merah kini dihitung di perangkat dan dilaporkan lewat field `isRedZone` pada `/devices/location`.

**Base URL**

| Lingkungan | URL |
| :--- | :--- |
| Produksi (Hugging Face Space) | `https://lintangnv-suar-backend.hf.space` |
| Lokal | `http://localhost:3000` |
| Swagger UI | `{base}/api/docs` |

Microservice OpenQuake dipanggil hanya oleh backend (`OPENQUAKE_MICROSERVICE_URL`, header `X-API-Key`); klien tidak mengaksesnya.

---

## 2. Konvensi

### 2.1 Format respons
- **Tidak ada envelope.** Respons sukses adalah objek/array/nilai asli endpoint, tanpa `success`, `data`, atau `meta` (kecuali endpoint yang secara eksplisit mengembalikan `success`, lihat `trigger-poll` dan `simulate`).
- **Kesalahan** memakai format bawaan NestJS:
```json
{ "message": "Perangkat dengan ID abc tidak ditemukan", "error": "Not Found", "statusCode": 404 }
```
- Parameter query yang tidak valid pada endpoint berpipa (`shelters/nearby`) menghasilkan `400` dengan pesan validasi Nest.
- **Body `POST` tidak divalidasi secara global** (belum ada `ValidationPipe`); klien wajib mengirim tipe yang benar.

### 2.2 Header dan autentikasi
- Kirim `Content-Type: application/json`.
- Backend **tidak membaca** header khusus (`X-Device-ID`, `X-App-Version`) dan **belum ada autentikasi**. Semua endpoint bersifat publik.

### 2.3 Koordinat
- Datum WGS 84 (EPSG:4326).
- Parameter query dan body memakai `latitude` dan `longitude` terpisah.
- GeoJSON pada respons mengikuti RFC 7946: `coordinates` berurutan **`[longitude, latitude]`**.
- Klien hanya memanggil `location` bila perangkat bergeser ≥ 1.000 m **atau** ≥ 30 menit sejak pengiriman terakhir.

### 2.4 Tipe angka
- `magnitude` pada `earthquake_alerts` bertipe `decimal`; driver PostgreSQL dapat mengirimnya sebagai **string** (mis. `"6.8"`). Klien harus menerima string maupun angka.

---

## 3. Devices

### 3.1 `POST /devices/register` (alias `POST /users/register-device`)
Membuat atau memperbarui perangkat. Bila koordinat rumah dikirim, backend mencari Vs30 dari raster tanah (default `270` m/s bila di luar cakupan).

**Body**
```json
{
  "deviceId": "c8a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "fcmToken": "token-fcm",
  "homeType": "Rumah",
  "homeLatitude": -7.7956,
  "homeLongitude": 110.3695
}
```
`deviceId` dan `fcmToken` wajib; sisanya opsional.

**Respons 201** — objek `UserDevice` yang tersimpan (contoh sebagian):
```json
{
  "id": "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
  "deviceId": "c8a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "fcmToken": "token-fcm",
  "homeType": "Rumah",
  "homeLocation": { "type": "Point", "coordinates": [110.3695, -7.7956] },
  "vs30": 270,
  "lastActive": "2026-09-20T07:30:00.000Z"
}
```
Field lain pada entitas (`lastLocation`, `isRedZone`, `createdAt`, `updatedAt`) dapat ikut dikembalikan. Kirim ulang endpoint ini setiap token FCM berganti.

### 3.2 `POST /devices/location` (alias `POST /users/update-location`)
**Body**
```json
{
  "deviceId": "c8a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "latitude": -7.0251,
  "longitude": 110.4208,
  "isRedZone": true
}
```
`isRedZone` **opsional** (boolean) dan dihitung oleh klien.

> [!WARNING]
> Field `isRedZone` menentukan apakah perangkat menerima push `TSUNAMI_EVACUATION_ALERT` (lihat bagian 6). Hanya perangkat dengan `isRedZone = true` yang menerimanya. Bila klien tidak mengirim field ini, nilainya tetap seperti sebelumnya (awal: `false`) dan perangkat tidak akan mendapat push evakuasi tsunami, hanya push guncangan.

**Respons 201** — objek `UserDevice` yang diperbarui (`lastLocation`, `vs30`, `isRedZone`, `lastActive`).
**Respons 404** — perangkat belum terdaftar; panggil `register` terlebih dulu.

---

## 4. Alerts (`/alerts`)

### 4.1 `GET /alerts/latest`
Gempa terbaru berdasarkan `alertTime`, termasuk yang tidak memenuhi ambang siaran (`isBroadcasted: false`). Bila belum ada data, backend mengembalikan `null` (body kosong).

**Respons 200**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "bmkgId": "4a7f21b9c8d3e...",
  "magnitude": "6.8",
  "depth": "15 km",
  "wilayah": "95 km BaratDaya BANYUWANGI-JATIM",
  "potensi": "Tidak berpotensi tsunami",
  "epicenter": { "type": "Point", "coordinates": [114.22, -8.45] },
  "isBroadcasted": true,
  "alertTime": "2026-09-20T06:15:20.000Z",
  "createdAt": "2026-09-20T06:15:25.120Z",
  "updatedAt": "2026-09-20T06:15:25.120Z"
}
```
- `bmkgId` adalah SHA-256 dari `DateTime_Coordinates` BMKG (untuk simulasi berformat `SIMULASI_<epoch>`).
- `potensi` dapat berupa **"Tidak berpotensi tsunami"**. Jangan mendeteksi tsunami dengan `contains('tsunami')`; periksa juga frasa `tidak berpotensi`.

### 4.2 `POST /alerts/calculate-impact`
Estimasi guncangan di lokasi pengguna dengan rumus atenuasi sederhana. Ini **bukan** hasil OpenQuake; MMI OpenQuake hanya dipakai backend untuk menyaring penerima push.

**Body**
```json
{ "earthquakeId": "550e8400-e29b-41d4-a716-446655440000", "latitude": -7.99, "longitude": 110.29 }
```
`earthquakeId` menerima `id` (UUID) atau `bmkgId`.

**Respons 200** (nilai pada contoh bersifat ilustrasi)
```json
{
  "earthquakeId": "550e8400-e29b-41d4-a716-446655440000",
  "bmkgId": "4a7f21b9c8d3e...",
  "magnitude": "6.8",
  "depth": "15 km",
  "wilayah": "95 km BaratDaya BANYUWANGI-JATIM",
  "potensi": "Tidak berpotensi tsunami",
  "isTsunamiPotential": false,
  "isUserInJawaBaliScope": true,
  "epicenter": { "latitude": -8.45, "longitude": 114.22 },
  "userLocation": { "latitude": -7.99, "longitude": 110.29 },
  "distanceKm": 412.55,
  "estimatedMmi": 4.1,
  "shakingLevel": "LIGHT",
  "alertTime": "2026-09-20T06:15:20.000Z"
}
```
`shakingLevel`: `MINOR` (MMI < 3), `LIGHT` (3 ≤ MMI < 5), `MODERATE` (5 ≤ MMI < 7), `VERY_SEVERE` (MMI ≥ 7). **Respons 404** bila alert tidak ditemukan.

### 4.3 `POST /alerts/trigger-poll` *(dev)*
Memicu satu siklus polling BMKG. **Respons 201:** `{ "success": true, "message": "BMKG Poll triggered manually" }`.

### 4.4 `POST /alerts/simulate` *(dev/QA)*
Memproses gempa simulasi seolah dari BMKG (melewati ambang dan dedup) dan mengirim FCM ke perangkat terdampak.

**Body**
```json
{
  "magnitude": 7.2,
  "depth": "10 km",
  "latitude": -7.02,
  "longitude": 110.32,
  "potensi": "Berpotensi tsunami",
  "wilayah": "25 km TimurLaut KOTA SEMARANG"
}
```
`depth` dapat berupa string atau angka (bawaan `"15"` bila kosong).

**Respons 201**
```json
{ "success": true, "alertId": "550e8400-e29b-41d4-a716-446655440000", "impactedCount": 142, "radiusInKm": 700 }
```
`radiusInKm` adalah radius pencarian awal (minimal 500 km, mengikuti jangkauan tsunami), atau radius dinamis (50–250 km) pada jalur cadangan.

> [!CAUTION]
> Endpoint ini belum diautentikasi dan mengirim push nyata ke perangkat yang berada dalam radius.

---

## 5. Shelters (`/shelters`)

`type` adalah **TPS** (Tempat Pengungsian Sementara) atau **TPA** (Tempat Pengungsian Akhir). Respons berupa objek `Shelter` apa adanya (tanpa `latitude`/`longitude`/`distanceKm`):

```json
{
  "id": "3f1c1a52-8a53-4a7d-9d4c-8c0f6a6f2b10",
  "name": "Titik Evakuasi TPA (TPA-01)",
  "type": "TPA",
  "location": { "type": "Point", "coordinates": [110.255611, -7.968502] },
  "capacity": 500,
  "currentEvacuees": 0,
  "status": "active",
  "notes": "Data evakuasi resmi BPBD Bantul (TPA)",
  "source": "digitized_bpbd_peta_2010",
  "createdAt": "2026-09-20T07:00:00.000Z",
  "updatedAt": "2026-09-20T07:00:00.000Z"
}
```

> [!NOTE]
> Pada data awal Bantul, `capacity` diisi angka **placeholder** (TPA = 500, TPS = 150) dan `currentEvacuees` = 0. Jangan menampilkannya sebagai data resmi sebelum diverifikasi.

### 5.1 `GET /shelters`
Semua titik evakuasi, terbaru lebih dulu. Query opsional: `type` (`TPS` | `TPA` | `ALL`; `ALL` sama dengan tanpa filter).

### 5.2 `GET /shelters/nearby`
Titik evakuasi berstatus `active` dalam radius.

| Query | Tipe | Keterangan |
| :--- | :--- | :--- |
| `latitude` | number | Wajib |
| `longitude` | number | Wajib |
| `radiusInKm` | **integer** | Opsional, default 50. Nilai desimal ditolak (`400`) |
| `type` | `TPS` \| `TPA` \| `ALL` | Opsional |

Respons: array `Shelter`.

### 5.3 `POST /shelters`
**Body**
```json
{
  "name": "Posko Evakuasi Parangtritis",
  "latitude": -7.968502,
  "longitude": 110.255611,
  "type": "TPA",
  "capacity": 500,
  "status": "active",
  "notes": "Akses mudah dari jalan utama",
  "source": "digitized_bpbd_peta_2010"
}
```
`latitude`, `longitude`, `type` wajib; sisanya opsional (`name` otomatis dibuat bila kosong). **Respons 201:** objek `Shelter`.

### 5.4 `PATCH /shelters/:id/evacuees`
**Body:** `{ "count": 320 }` (integer; nilai negatif dijepit ke 0). **Respons 200:** objek `Shelter` yang diperbarui. **404** bila `id` tidak ada.

### 5.5 `POST /shelters/seed`
Mengisi data titik evakuasi Bantul (idempoten; melewati titik yang berjarak ≤ 50 m dari data yang ada). **Respons 201:** `{ "seeded": 19, "total": 19 }`.

---

## 6. Push Notification FCM

### 6.1 Kapan alert diproses
Backend mengambil data BMKG tiap 30 detik. Gempa disiarkan bila **M ≥ 5.0**, **kedalaman ≤ 300 km**, dan berada di atau berdampak ke Jawa-Bali. Simulasi melewati ambang ini.

### 6.2 Dua jenis push

| `data.type` | Penerima | `statusTindakan` |
| :--- | :--- | :--- |
| `TSUNAMI_EVACUATION_ALERT` | Perangkat dengan `isRedZone = true` dalam jangkauan tsunami dari episentrum | `EVAKUASI TSUNAMI` |
| `EARTHQUAKE_ALERT` | Perangkat dengan MMI ≥ V (hasil OpenQuake) yang tidak menerima push tsunami | `BERLINDUNG` |

- **Potensi tsunami** bila `potensi` tidak memuat "tidak berpotensi" **dan** (memuat "tsunami" atau (M ≥ 6.5 **dan** kedalaman ≤ 100 km)).
- **Jangkauan tsunami** (jarak dari episentrum): M ≥ 8 → 1.200 km, M ≥ 7 → 700 km, M ≥ 6.5 → 400 km, selain itu 250 km. Pencarian kandidat memakai radius terbesar antara 500 km dan jangkauan itu.
- **Jalur cadangan** (microservice OpenQuake tidak tersedia): backend memakai radius dinamis (50–250 km, dikurangi faktor kedalaman) dan mengirim satu jenis push ke semua perangkat dalam radius, tanpa memeriksa `isRedZone`: `TSUNAMI_EVACUATION_ALERT` bila ada potensi tsunami, selain itu `EARTHQUAKE_ALERT`.
- Token berawalan `mock_token_` disaring.

### 6.3 Format pesan

```json
{
  "notification": {
    "title": "🚨 PERINGATAN EVAKUASI TSUNAMI (SUAR)",
    "body": "Peringatan Tsunami! Gempa M 7.2 Mw di 25 km TimurLaut KOTA SEMARANG. Anda berada di Zona Merah Tsunami. Segera evakuasi ke TPS/TPA!"
  },
  "data": {
    "type": "TSUNAMI_EVACUATION_ALERT",
    "magnitude": "7.2",
    "depth": "10 km",
    "wilayah": "25 km TimurLaut KOTA SEMARANG",
    "potensi": "Berpotensi tsunami",
    "statusTindakan": "EVAKUASI TSUNAMI",
    "coordinates": "-7.02,110.32",
    "dateTime": "2026-09-20T06:15:20.000Z",
    "isSimulation": "false"
  },
  "android": {
    "priority": "high",
    "notification": { "channelId": "suar_darurat_v5" }
  }
}
```

- Judul `EARTHQUAKE_ALERT`: "⚠️ PERINGATAN GEMPA BUMI (SUAR)"; isi: "Gempa M {M} Mw, Kedalaman {d} km. Wilayah: {wilayah}. Status: BERLINDUNG." Judul dan isi berawalan `[SIMULASI]` untuk simulasi.
- `coordinates` berformat `"lat,lng"` (berbeda dari urutan GeoJSON).
- Payload **tidak memuat** MMI/PGA. Ambil detail lewat `GET /alerts/latest` dan `POST /alerts/calculate-impact`.
- `channelId` harus sudah dibuat di perangkat (aplikasi membuatnya saat inisialisasi notifikasi); bila belum, Android memakai kanal bawaan FCM tanpa suara alarm.

### 6.4 Perilaku klien
- App terbuka: menampilkan notifikasi lokal beralarm dengan payload `REAL_EWS`.
- App di latar belakang atau tertutup: sistem menampilkan notifikasi; saat di-tap, klien memakai payload `REAL_EWS`.
- Payload `REAL_EWS` memicu pengambilan `/alerts/latest`, filter signifikansi di klien, dan analisis triage.
- Klien mengenali kedua nilai `data.type` di atas.

---

## 7. Model di Frontend

Frontend memakai model sendiri, bukan cuplikan `freezed`/`json_serializable` pada v1.0.0:

| Data | Model | Berkas |
| :--- | :--- | :--- |
| `GET /alerts/latest` | `GempaModel.fromBackendJson` | `frontend/lib/features/ews_ai/domain/gempa_model.dart` |
| `POST /alerts/calculate-impact` | `ImpactEstimate` | `frontend/lib/features/ews_ai/domain/impact_estimate_model.dart` |
| `GET /shelters/nearby` | `Shelter` | `frontend/lib/features/map_evacuation/domain/shelter_model.dart` |

---

## 8. Hierarki Cadangan di Klien

Data gempa:
1. **Utama:** `GET {backend}/alerts/latest`.
2. **Cadangan online:** BMKG `autogempa.json`.
3. **Cadangan luring:** data statis "Mode Luring" bawaan aplikasi (magnitudo 4.1, tidak berpotensi tsunami).

Status zona merah tsunami: dihitung di klien dari API InaRISK BNPB. Bila gagal, klien saat ini menganggap titik **bukan** zona merah.

Titik evakuasi: hasil `GET /shelters/nearby` terakhir disimpan lokal dan dipakai saat backend tidak terjangkau.
