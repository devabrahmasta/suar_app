# 📜 Kontrak API & Spesifikasi Teknis (API Contract Document)
## Project SUAR — Sistem Ubiquitous Adaptif Respons
**Versi Kontrak:** 1.0.0  
**Tanggal Rilis:** Maret 2026  
**Penyusun:** Backend Lead  
**Target Pengguna:** Mobile Frontend Team (Flutter)  
**Status Modul Backend:** Partial / In-Progress (Siap untuk Parallel Development & Mocking)

---

> [!IMPORTANT]
> **Dokumen Panduan Kerja Tim Frontend**  
> Dokumen ini disusun agar Tim Frontend dapat membangun Data Model, Repository, State Management (Riverpod), serta UI Screen secara **100% paralel** tanpa bergantung pada penyelesaian backend cloud. Semua format *request*, *response*, *data types*, dan *error payloads* di bawah ini telah dikunci (*frozen contract*).

---

## 1. Overview & Arsitektur Integrasi

Aplikasi **SUAR** beroperasi dengan arsitektur **Hybrid Online-Offline (Offline-First)**:
1. **Mode Online (Cloud Backend):** Selagi koneksi seluler/internet tersedia, perangkat berkomunikasi dengan **NestJS Cloud Backend + PostGIS** untuk registrasi FCM token, sinkronisasi titik lokasi geospasial, polling gempa real-time BMKG, pengecekan zona merah tsunami, serta sinkronisasi daya tampung posko evakuasi.
2. **Mode Offline (Mesh Network + Local Cache):** Saat internet mati akibat bencana, frontend beralih ke **Bluetooth/WiFi Direct Mesh Network** dan data geospasial lokal (SQLite FMTC + GeoJSON asset) dengan *graceful degradation*.

```
+------------------+         REST / Tile          +-----------------------+
| Mobile Frontend  | ---------------------------> | NestJS Backend        |
| (Flutter/Dart)   | <--------------------------- | (PostgreSQL + PostGIS)|
+------------------+     FCM Push Notification    +-----------------------+
        |                                                    |
        | (Fallback saat Offline)                            | Internal API Key
        v                                                    v
+------------------+                              +-----------------------+
| Local SQLite /   |                              | OpenQuake Python      |
| Mesh Network     |                              | Hazard Microservice   |
+------------------+                              +-----------------------+
```

### 1.1 Base Environment URLs

| Environment | Base URL | Keterangan |
| :--- | :--- | :--- |
| **Local Development** | `http://localhost:3000` | Testing backend lokal (Docker/NestJS) |
| **Staging / Cloud** | `https://suar-backend-dev.hf.space` | Cloud Deployment (Hugging Face Spaces) |
| **OpenQuake Microservice** | `https://suar-openquake.hf.space` | Service-to-service PGA & MMI engine |

### 1.2 Global Request Headers

Setiap HTTP Request dari aplikasi Flutter wajib menyertakan header berikut:

```http
Content-Type: application/json
Accept: application/json
X-Device-ID: uuid-v4-unique-device-id
X-App-Version: 1.0.0
```

---

## 2. Standard Envelope & Error Response Format

Untuk konsistensi parsing JSON di sisi Flutter, backend menggunakan **Standard Global Envelope Format**.

### 2.1 Success Response Envelope (HTTP 200 / 201)

```json
{
  "success": true,
  "statusCode": 200,
  "message": "Deskripsi singkat hasil operasi",
  "data": { ... },
  "meta": {
    "timestamp": "2026-03-31T14:30:00.000Z"
  }
}
```
*(Catatan: Beberapa endpoint langsung mengembalikan object data utama atau array untuk performa tile geospasial).*

### 2.2 Error Response Envelope (HTTP 4xx / 5xx)

```json
{
  "success": false,
  "statusCode": 400,
  "message": "Validasi input gagal",
  "errorDetails": [
    "latitude must be a latitude coordinate",
    "fcmToken should not be empty"
  ],
  "timestamp": "2026-03-31T14:30:00.000Z"
}
```

---

## 3. Konvensi Geospasial & Aturan Koordinat

1. **Sistem Koordinat (Datum):** Selalu menggunakan **WGS 84 (EPSG:4326)**.
2. **Format Parameter Query REST API:** `latitude` (double) dan `longitude` (double) dipisah sebagai query parameter individual.
3. **Format GeoJSON (Database & Cache):** Sesuai standar RFC 7946, array koordinat berurutan `[longitude, latitude]`.
4. **Optimasi Interval Update Geospasial Perangkat:**
   * Flutter **hanya** mengirim request `update-location` ke backend jika perangkat telah **berpindah ≥ 1.000 meter (1 km)** ATAU **waktu berlalu ≥ 30 menit** sejak update lokasi terakhir.

---

## 4. Spesifikasi REST API Endpoint per Modul

---

### 📱 Modul 1: User & Device Registration (`/users`)

Modul ini menangani pendaftaran token FCM perangkat fisik dan sinkronisasi koordinat GPS lokasi aktif pengguna untuk penargetan notifikasi bencana geospasial (*geofencing*).

#### 1.1 `POST /users/register-device`
Membuat atau memperbarui profil perangkat pengguna dan token FCM push notification saat onboarding aplikasi.

* **Request Body:**
```json
{
  "deviceId": "c8a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "fcmToken": "fcm_token_string_from_firebase_messaging_sdk",
  "homeType": "Rumah",
  "homeLatitude": -7.7956,
  "homeLongitude": 110.3695
}
```
* **Field Specifications:**
  * `deviceId` (string, **Required**): Unique Identifer HP (UUID v4 / Android ID).
  * `fcmToken` (string, **Required**): Firebase Push Notification Token.
  * `homeType` (string, *Optional*): Jenis hunian (`"Rumah"`, `"Apartemen"`, `"Ruko"`).
  * `homeLatitude` (number, *Optional*): Lintang tempat tinggal (-90 s.d 90).
  * `homeLongitude` (number, *Optional*): Bujur tempat tinggal (-180 s.d 180).

* **Response 201 (Created / Success):**
```json
{
  "id": "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
  "deviceId": "c8a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "fcmToken": "fcm_token_string_from_firebase_messaging_sdk",
  "homeType": "Rumah",
  "lastLocation": {
    "type": "Point",
    "coordinates": [110.3695, -7.7956]
  },
  "updatedAt": "2026-03-31T14:30:00.000Z"
}
```

---

#### 1.2 `POST /users/update-location`
Memperbarui lokasi GPS aktif terakhir perangkat pengguna (*background service location sync*).

* **Request Body:**
```json
{
  "deviceId": "c8a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "latitude": -7.0251,
  "longitude": 110.4208
}
```

* **Response 201 (Success):**
```json
{
  "success": true,
  "message": "User location updated successfully",
  "deviceId": "c8a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "location": {
    "latitude": -7.0251,
    "longitude": 110.4208
  }
}
```

* **Response 404 (Not Found):**
```json
{
  "success": false,
  "statusCode": 404,
  "message": "Device with ID c8a1b2c3-... not registered. Please call /users/register-device first."
}
```

---

### 🚨 Modul 2: Early Warning System (EWS) Gempa (`/alerts`)

Modul EWS memantau data real-time BMKG, melakukan de-duplikasi gempa, mengkalkulasi radius bahaya geospasial, dan menyajikan data gempa terbersih ke aplikasi Flutter.

#### 2.1 `GET /alerts/latest`
Mengambil data gempa bumi terbaru yang telah diverifikasi dan diproses oleh server EWS.

* **Query Parameters:** Tidak ada.
* **Response 200 (Success):**
```json
{
  "id": "eq-20260331-001",
  "bmkgId": "20260331141520",
  "datetime": "2026-03-31T14:15:20.000Z",
  "magnitude": 6.8,
  "depthKm": 15.0,
  "latitude": -8.45,
  "longitude": 114.22,
  "wilayah": "95 km BaratDaya BANYUWANGI-JATIM",
  "potensi": "Berpotensi Tsunami",
  "dirasakan": "IV-V Banyuwangi, III-IV Denpasar, III Kuta",
  "impactRadiusKm": 250.0,
  "isTsunamiPotential": true,
  "createdAt": "2026-03-31T14:15:25.120Z"
}
```

---

#### 2.2 `POST /alerts/trigger-poll` *(Endpoint Pengujian / Dev Only)*
Memicu polling manual backend ke API BMKG (`gempaterkini.json`).

* **Request Body:** `{}`
* **Response 201 (Success):**
```json
{
  "success": true,
  "message": "BMKG Poll triggered manually"
}
```

---

#### 2.3 `POST /alerts/simulate` *(Endpoint Pengujian QA / Frontend Simulator)*
Menyimulasikan skenario gempa kustom untuk menguji alarm suara darurat dan geofencing radius bahaya pada handphone penguji.

* **Request Body:**
```json
{
  "magnitude": 7.2,
  "depth": "10 km",
  "latitude": -7.02,
  "longitude": 110.32,
  "potensi": "Berpotensi TSUNAMI di Pesisir Jawa Tengah",
  "wilayah": "25 km TimurLaut KOTA SEMARANG"
}
```
* **Response 201 (Success):**
```json
{
  "success": true,
  "message": "Simulated alert broadcasted to 142 affected devices",
  "alertId": "sim-88129381",
  "impactRadiusKm": 250
}
```

---

### 🌊 Modul 3: Zona Merah Tsunami & Layer Peta Vektor (`/alerts/tsunami-*`)

Modul ini menyajikan pengecekan presisi tinggi Point-in-Polygon zona bahaya tsunami berbasis PostGIS spatial query untuk wilayah **Jawa & Bali**, serta menyediakan ubin (tile) visual peta.

#### 3.1 `GET /alerts/tsunami-check`
Mengecek secara real-time apakah koordinat GPS pengguna berada di dalam Polygon Zona Merah Bahaya Tsunami (Jawa & Bali).

* **Query Parameters:**
  * `latitude` (number, **Required**): Contoh `-7.02`
  * `longitude` (number, **Required**): Contoh `110.32`

* **Response 200 (Zona Merah / Bahaya):**
```json
{
  "isRedZone": true,
  "hazardLevel": "HIGH",
  "zoneDetails": {
    "region": "Pesisir Utara Jawa Tengah / Semarang",
    "riskType": "Tsunami Hazard Zone - High Vulnerability",
    "recommendedAction": "SEGERA LAKUKAN EVAKUASI KE DATARAN TINGGI (MINIMAL ELEVASI 20 METER)"
  },
  "location": {
    "latitude": -7.02,
    "longitude": 110.32
  }
}
```

* **Response 200 (Zona Aman / Daratan):**
```json
{
  "isRedZone": false,
  "hazardLevel": "SAFE",
  "zoneDetails": null,
  "location": {
    "latitude": -7.7956,
    "longitude": 110.3695
  }
}
```

---

#### 3.2 `GET /alerts/tsunami-tile/{z}/{x}/{y}.svg`
Menyuplai ubin vektor SVG transparan zona bahaya tsunami untuk dirender langsung oleh `flutter_map` saat online.

* **Path Parameters:** `z` (zoom level, e.g. 14), `x` (tile X index), `y` (tile Y index).
* **Response Header:** `Content-Type: image/svg+xml`, `Cache-Control: public, max-age=86400`
* **Response Body:** Data Biner SVG.

---

#### 3.3 `GET /alerts/tsunami-tile/{z}/{x}/{y}.pbf`
Menyuplai Mapbox Vector Tile (MVT) standar protobuf untuk pengisian tile caching luring (FMTC).

* **Path Parameters:** `z`, `x`, `y`.
* **Response Header:** `Content-Type: application/x-protobuf`
* **Response Body:** Binary Protocol Buffer.

---

### 🏰 Modul 4: Posko & Titik Kumpul Evakuasi / Shelters (`/shelters`)

Modul ini mengelola data Single Source of Truth (SSOT) posko evakuasi bencana, lokasi geospasial, daya tampung (kapasitas), dan update real-time jumlah pengungsi.

#### 4.1 `GET /shelters`
Mengambil seluruh daftar posko evakuasi terdaftar.

* **Response 200 (Success):**
```json
[
  {
    "id": "shelter-001",
    "name": "Stadion Maguwoharjo (Titik Kumpul Utama)",
    "location": {
      "type": "Point",
      "coordinates": [110.4178, -7.7584]
    },
    "latitude": -7.7584,
    "longitude": 110.4178,
    "capacity": 5000,
    "currentEvacuees": 1240,
    "status": "active",
    "notes": "Fasilitas: Listrik Genset, Dapur Umum, Posko Kesehatan",
    "createdAt": "2026-03-01T08:00:00.000Z"
  }
]
```

---

#### 4.2 `GET /shelters/nearby`
Mencari posko evakuasi terdekat di sekitar lokasi GPS pengguna menggunakan PostGIS `ST_DWithin`.

* **Query Parameters:**
  * `latitude` (number, **Required**): Contoh `-7.79`
  * `longitude` (number, **Required**): Contoh `110.36`
  * `radiusInKm` (number, *Optional*, Default: `50`): Radius pencarian dalam kilometer.

* **Response 200 (Success):**
```json
[
  {
    "id": "shelter-002",
    "name": "SMA Negeri 1 Godean",
    "location": {
      "type": "Point",
      "coordinates": [110.2945, -7.7681]
    },
    "latitude": -7.7681,
    "longitude": 110.2945,
    "capacity": 800,
    "currentEvacuees": 150,
    "distanceKm": 4.2,
    "status": "active",
    "notes": "Tersedia area helipad darurat dan pasokan air bersih."
  }
]
```

---

#### 4.3 `POST /shelters`
Mendaftarkan posko evakuasi baru oleh petugas atau admin lapangan.

* **Request Body:**
```json
{
  "name": "Gedung Serbaguna Kelurahan Depok",
  "latitude": -7.7621,
  "longitude": 110.3912,
  "capacity": 600,
  "notes": "Posko sekunder bencana gempa/banjir"
}
```

* **Response 201 (Created):** Mengembalikan objek `Shelter` lengkap.

---

#### 4.4 `PATCH /shelters/{id}/evacuees`
Memperbarui jumlah statistik pengungsi secara real-time.

* **Request Body:**
```json
{
  "count": 320
}
```

* **Response 200 (Success):**
```json
{
  "id": "shelter-001",
  "name": "Stadion Maguwoharjo",
  "capacity": 5000,
  "currentEvacuees": 320,
  "updatedAt": "2026-03-31T15:00:00.000Z"
}
```

---

## 5. Kontrak Payload Push Notification FCM (Firebase Cloud Messaging)

Ketika BMKG merilis data gempa signifikan (Mag ≥ 5.0 atau Potensi Tsunami), Cloud Backend mengirim pesan FCM **High Priority** langsung ke HP pengguna yang berada dalam radius bahaya:

### 5.1 FCM Data Payload Schema (Silent & High Priority Trigger)

```json
{
  "message": {
    "token": "target_device_fcm_token",
    "priority": "HIGH",
    "data": {
      "click_action": "FLUTTER_NOTIFICATION_CLICK",
      "type": "EARTHQUAKE_EWS_ALERT",
      "alertId": "eq-20260331-001",
      "magnitude": "6.8",
      "depth": "15.0",
      "latitude": "-8.45",
      "longitude": "114.22",
      "wilayah": "95 km BaratDaya BANYUWANGI-JATIM",
      "potensi": "Berpotensi Tsunami",
      "impactRadiusKm": "250.0",
      "isTsunami": "true",
      "timestamp": "1774966520000"
    }
  }
}
```

> [!NOTE]
> **Tindakan Perangkat Flutter saat Menerima FCM Payload:**
> 1. Memutar suara sirene alarm darurat (*Foreground Service Audio Player*).
> 2. Memicu analisis AI Triage (Google Gemini Flash) untuk menyusun instruksi evakuasi spesifik berdasarkan lokasi & kerentanan rumah.
> 3. Memicu proses unduh otomatis ubin peta offline (JIT Map Download 3 KM).

---

## 6. Dart Data Model Ready-to-Use Code Snippets (Flutter)

Tim Frontend dapat langsung men-copypaste DTO / Model Dart berikut ke codebase Flutter (`lib/features/.../data/models/`):

### 6.1 `EarthquakeAlertModel` (`earthquake_alert_model.dart`)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'earthquake_alert_model.g.dart';

@JsonSerializable()
class EarthquakeAlertModel {
  final String id;
  final String bmkgId;
  final DateTime datetime;
  final double magnitude;
  final double depthKm;
  final double latitude;
  final double longitude;
  final String wilayah;
  final String potensi;
  final String? dirasakan;
  final double impactRadiusKm;
  final bool isTsunamiPotential;

  EarthquakeAlertModel({
    required this.id,
    required this.bmkgId,
    required this.datetime,
    required this.magnitude,
    required this.depthKm,
    required this.latitude,
    required this.longitude,
    required this.wilayah,
    required this.potensi,
    this.dirasakan,
    required this.impactRadiusKm,
    required this.isTsunamiPotential,
  });

  factory EarthquakeAlertModel.fromJson(Map<String, dynamic> json) =>
      _$EarthquakeAlertModelFromJson(json);

  Map<String, dynamic> toJson() => _$EarthquakeAlertModelToJson(this);
}
```

### 6.2 `TsunamiCheckResult` (`tsunami_check_result.dart`)

```dart
class TsunamiCheckResult {
  final bool isRedZone;
  final String hazardLevel;
  final String? recommendedAction;
  final double latitude;
  final double longitude;

  TsunamiCheckResult({
    required this.isRedZone,
    required this.hazardLevel,
    this.recommendedAction,
    required this.latitude,
    required this.longitude,
  });

  factory TsunamiCheckResult.fromJson(Map<String, dynamic> json) {
    return TsunamiCheckResult(
      isRedZone: json['isRedZone'] ?? false,
      hazardLevel: json['hazardLevel'] ?? 'SAFE',
      recommendedAction: json['zoneDetails']?['recommendedAction'],
      latitude: (json['location']?['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['location']?['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
```

---

## 7. Strategi Mocking & Development Paralel Frontend

Agar pengembangan Flutter tidak terhambat saat backend sedang tahap penyelesaian atau deployment:

1. **Mocktail / Dio Adapter Injection:**
   Tim Frontend disarankan menggunakan `DioAdapter` (dari package `http_mock_adapter`) untuk mengembalikan payload JSON contoh dari dokumen ini pada mode `kDebugMode`.
2. **Hybrid Fallback Hierarchy (Keandalan Sistem):**
   Frontend wajib mengimplementasikan pola 3 lapis fallback:
   * **Lapis 1 (Utama):** NestJS Cloud Backend (`https://suar-backend-dev.hf.space/alerts/latest`).
   * **Lapis 2 (Fallback Online 1):** API BMKG Langsung (`https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json`).
   * **Lapis 3 (Fallback Offline Total):** GeoJSON Aset Lokal (`assets/data/tsunami_jawa_bali_mobile.geojson`) + Bluetooth/WiFi Direct Mesh Chat.

---
*Dokumen ini bersifat resmi dan terkunci sebagai acuan integrasi Frontend SUAR App v1.0.0.*
