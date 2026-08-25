---
title: suar-backend
sdk: docker
pinned: false
---

# SUAR EWS Backend (NestJS Cloud Server)

> **Cloud Backend & Spatial Processing Engine for Early Warning System (EWS) SUAR - Built with NestJS, PostGIS, Firebase Admin, and OpenQuake Integration.**

---

## Overview

Backend SUAR berfungsi sebagai pusat pemrosesan sinyal kebencanaan, pemantauan latar belakang (background polling BMKG), manajemen perangkat pengguna, kueri spasial geospasial berbasis PostGIS, dan pengiriman notifikasi darurat (Emergency Push Notification FCM).

Backend ini terintegrasi langsung dengan Python OpenQuake Hazard Microservice untuk menghitung estimasi percepatan tanah puncak (PGA) dan skala intensitas guncangan (MMI) secara akurat menggunakan model fisik GMPE (Ground Motion Prediction Equations).

---

## Standar Threshold Statis EWS (BMKG InaTEWS & Seismic Hazard Standard)

Berikut adalah konstanta ambang statis resmi EWS yang dikonfigurasi di `AlertsService`:

```typescript
public static readonly MIN_MAGNITUDE_EWS = 5.0;     // Magnitudo (Mw) minimum untuk memicu kalkulasi bahaya spasial
public static readonly MAX_DEPTH_EWS = 300.0;         // Kedalaman hipotetis maksimum (km) untuk bahaya guncangan
public static readonly TSUNAMI_MIN_MAGNITUDE = 6.5;   // Magnitudo (Mw) minimum untuk bahaya potensi tsunami
public static readonly TSUNAMI_MAX_DEPTH = 100.0;      // Kedalaman maksimum (km) untuk deformasi dasar laut & tsunami
```

---

## Fitur Utama Backend

- **BMKG Real-Time Polling & De-duplikasi:**
  - Melakukan polling otomatis ke API EWS BMKG setiap 30 detik (`@Interval(30000)`).
  - Melakukan de-duplikasi alert menggunakan kalkulasi hash SHA-256 (`DateTime` + `Coordinates`).
- **Integrasi OpenQuake Hazard Engine:**
  - Mengambil data kedalaman subduksi Slab2 dan ketidakpastian (`slab2_depth_raster` / `slab2_unc_raster`).
  - Melakukan penyaringan awal (*coarse filter*) pengguna dalam radius jangkauan dampak via PostGIS `ST_DWithin`.
  - Mengirim parameter gempa & koordinat pengguna ke OpenQuake Microservice via REST API (`/calculate-hazard`) yang dilindungi `X-API-Key`.
  - Memicu notifikasi FCM darurat hanya untuk perangkat dengan hasil kalkulasi $\text{MMI} \ge \text{V}$.
- **Notifikasi Terfilter Jarak Zona Merah Tsunami:**
  - Menghitung radius jangkauan tsunami (`tsunamiReachRadius`).
  - Memastikan hanya perangkat pengguna di zona merah yang berada dalam radius jangkauan tsunami dari episenter yang menerima notifikasi `TSUNAMI_EVACUATION_ALERT` (perintah `EVAKUASI TSUNAMI`).
- **Pendaftaran Perangkat & Lookup $V_{s30}$ Spasial:**
  - Menyimpan token FCM, jenis rumah, koordinat rumah, dan lokasi aktif terakhir (`lastLocation`).
  - Mengambil data $V_{s30}$ (kecepatan gelombang geser 30 meter teratas) secara otomatis melalui kueri raster PostGIS `ST_Value` dari tabel `vs30_soil_raster` (fallback ke default `270.0` m/s).
- **Streaming GeoJSON & HTTP ETag Caching:**
  - Menyajikan aset GeoJSON zona merah tsunami Jawa-Bali (`/tsunami/geojson/jawa-bali`) terkompresi `.gz` dengan HTTP `ETag` (SHA-256) dan response header `304 Not Modified` untuk menghemat kuota internet pengguna.
- **Dokumentasi API Interaktif Swagger UI:**
  - Dokumentasi API lengkap yang tergenerasi secara otomatis di `/api/docs`.

---

## Spesifikasi Kueri Spasial PostGIS

Sistem menggunakan kueri spasial PostGIS `ST_Value` berbasis data raster GeoTIFF yang telah diunggah ke database PostgreSQL (Supabase / Local Docker PostGIS):

### 1. Kueri Lookup Amplifikasi $V_{s30}$ (`users.service.ts`)
Mengambil nilai kecepatan gelombang geser 30m teratas ($V_{s30}$) berdasarkan lokasi perangkat:
```sql
SELECT ST_Value(rast, ST_SetSRID(ST_Point($1, $2), 4326)) AS vs30
FROM vs30_soil_raster
WHERE ST_Intersects(rast, ST_SetSRID(ST_Point($1, $2), 4326))
LIMIT 1;
```
- **Parameter:** `$1 = longitude`, `$2 = latitude` (Urutan standar PostGIS).
- **Fallback:** Mengembalikan `270.0` m/s (SNI 1726:2019 kelas tanah SD) jika koordinat di luar cakupan raster.

### 2. Kueri Realtime & Tile Server Zona Merah Tsunami Jawa & Bali (`tsunami.service.ts`)
Mengecek apakah koordinat pengguna berada di dalam poligon bahaya tsunami (Jawa & Bali) secara realtime:
```sql
SELECT EXISTS (
  SELECT 1 FROM tsunami_hazard_polygons
  WHERE ST_Contains(geom, ST_SetSRID(ST_Point($1, $2), 4326))
) AS is_red_zone;
```
- **Performa:** Kueri spasial diproses dalam hitungan < 2 ms menggunakan spatial index `GIST`.
- **Tile Server Overlay (`/tsunami/tile/:z/:x/:y.svg` & `.pbf`):** Meng-generate ubin peta vektor SVG/MVT transparan untuk visualisasi overlay pada Map Engine.

---

## Teknologi yang Digunakan

- **Framework:** NestJS 11.x (Node.js 18+)
- **ORM & Data:** TypeORM & PostgreSQL + PostGIS Extension
- **Database Backend:** Supabase PostgreSQL / Local Docker PostGIS
- **Push Notification:** Firebase Admin SDK (FCM)
- **API Documentation:** `@nestjs/swagger` & Swagger UI
- **Containerization:** Docker & Docker Compose

---

## Spesifikasi Endpoint Utama

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/health` | Server health check & status diagnostik |
| `POST` | `/devices/register` | Mendaftarkan/memperbarui token FCM & lokasi rumah perangkat |
| `POST` | `/devices/location` | Memperbarui lokasi GPS aktif perangkat, flag `isRedZone`, & menghitung $V_{s30}$ |
| `POST` | `/alerts/calculate-impact` | Menghitung jarak pengguna dari episenter, intensitas MMI, & status potensi tsunami |
| `GET` | `/shelters?type=ALL` | Mengambil seluruh titik evakuasi resmi (TPS + TPA) |
| `GET` | `/tsunami/geojson/jawa-bali` | Stream aset GeoJSON terkompresi `.gz` dengan HTTP ETag caching |
| `POST` | `/tsunami/verify-location` | Verifikasi kueri spasial PostGIS Point-in-Polygon zona merah tsunami |
