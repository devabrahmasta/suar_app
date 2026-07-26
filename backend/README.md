---
title: suar-backend
emoji: 🔔
colorFrom: blue
colorTo: red
sdk: docker
pinned: false
---

# 🔔 SUAR EWS Backend (NestJS Cloud Server)

> **Cloud Backend & Spatial Processing Engine for Early Warning System (EWS) SUAR - Built with NestJS, PostGIS, Firebase Admin, and OpenQuake Integration.**

---

## 📖 Overview

Backend **SUAR** berfungsi sebagai pusat pemrosesan sinyal kebencanaan, pemantauan latar belakang (background polling BMKG), manajemen perangkat pengguna, kueri spasial geospasial berbasis PostGIS, dan pengiriman notifikasi darurat (*Emergency Push Notification FCM*).

Backend ini terintegrasi langsung dengan **Python OpenQuake Hazard Microservice** untuk menghitung estimasi percepatan tanah puncak (**PGA**) dan skala intensitas guncangan (**MMI**) secara akurat menggunakan model fisik GMPE (*Ground Motion Prediction Equations*).

---

## ✨ Fitur Utama Backend

- **BMKG Real-Time Polling & De-duplikasi:**
  - Melakukan polling otomatis ke API EWS BMKG setiap 30 detik (`@Interval(30000)`).
  - Melakukan de-duplikasi alert menggunakan kalkulasi hash SHA-256 (`DateTime` + `Coordinates`).
- **Integrasi OpenQuake Hazard Engine:**
  - Mengambil data kedalaman subduksi Slab2 dan ketidakpastian (`slab2_depth_raster` / `slab2_unc_raster`).
  - Melakukan penyaringan awal (*coarse filter*) pengguna dalam radius 500 KM via PostGIS `ST_DWithin`.
  - Mengirim parameter gempa & koordinat pengguna ke OpenQuake Microservice via REST API (`/calculate-hazard`) yang dilindungi `X-API-Key`.
  - Memicu notifikasi FCM darurat hanya untuk perangkat dengan hasil kalkulasi $\text{MMI} \ge \text{V}$.
- **Mitigasi Cold-Start & Keep-Alive Ping:**
  - Memicu pings otomatis ke endpoint `/health` milik microservice pada setiap siklus polling untuk menjaga container Hugging Face Space tetap aktif (*awake*).
- **Fallback Radius Dinamis (Phase 2 Fallback):**
  - Mengaktifkan algoritma peredaman kedalaman (*Depth Attenuation Factor*) dan potensi tsunami sebagai fallback jika microservice tidak tersedia.
- **Pendaftaran Perangkat & Lookup $V_{s30}$ Spasial:**
  - Menyimpan token FCM, jenis rumah, koordinat rumah, dan lokasi aktif terakhir (`lastLocation`).
  - Mengambil data $V_{s30}$ (kecepatan gelombang geser 30 meter teratas) secara otomatis melalui kueri raster PostGIS `ST_Value` dari tabel `vs30_soil_raster` (fallback ke default `270.0` m/s).
- **Dokumentasi API Interaktif Swagger UI:**
  - Dokumentasi API lengkap yang tergenerasi secara otomatis di `/api/docs`.

---

## 🛠️ Teknologi yang Digunakan

- **Framework:** NestJS 10.x (Node.js 18+)
- **ORM & Data:** TypeORM & PostgreSQL + PostGIS Extension
- **Database Backend:** Supabase PostgreSQL / Local Docker PostGIS
- **Push Notification:** Firebase Admin SDK (FCM)
- **API Documentation:** `@nestjs/swagger` & Swagger UI
- **Containerization:** Docker & Docker Compose

---

## 📁 Struktur Direktori Backend

```
backend/
├── src/
│   ├── alerts/                    # Modul EWS: BMKG polling, hash dedup, OpenQuake integration, FCM push
│   │   ├── entities/              # Entity EarthquakeAlert
│   │   ├── alerts.controller.ts   # Controller EWS & endpoint simulasi
│   │   ├── alerts.service.ts      # Service logika EWS, Slab2 lookup, OpenQuake REST call, FCM
│   │   └── alerts.service.spec.ts # Unit testing EWS
│   ├── users/                     # Modul Pengguna & Perangkat
│   │   ├── entities/              # Entity UserDevice (termasuk kolom vs30)
│   │   ├── users.controller.ts    # Controller pendaftaran perangkat & update lokasi
│   │   └── users.service.ts       # Service pendaftaran & vs30 raster lookup
│   ├── firebase/                  # Modul integrasi Firebase Admin FCM
│   ├── app.module.ts              # Root NestJS module
│   └── main.dart / main.ts        # Entry point bootstrap server & Swagger setup
├── test/                          # End-to-End (E2E) spec tests
├── Dockerfile                     # Deployment Docker container untuk Hugging Face Spaces
└── docker-compose.yml             # Local PostGIS container configuration
```

---

## ⚙️ Environment Variables (`.env`)

Buat berkas `.env` di direktori `backend/`:

```env
PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=your_password
DB_DATABASE=postgres

# OpenQuake Microservice Config
OPENQUAKE_MICROSERVICE_URL=http://localhost:8000
OPENQUAKE_API_KEY=suar_secret_key_123

# Firebase Config (Optional for push notifications)
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@your-project.iam.gserviceaccount.com
```

---

## 🚀 Panduan Memulai & Pengujian

### 1. Instal Dependensi
```bash
npm install
```

### 2. Jalankan Database PostGIS (Lokal Docker)
```bash
docker compose up -d
```

### 3. Jalankan Server Development
```bash
npm run start:dev
```

Server akan berjalan pada `http://localhost:3000`. Akses Swagger UI di `http://localhost:3000/api/docs`.

### 4. Jalankan Unit Test Otomatis
```bash
npm run test
```

### 5. Kompilasi Produksi (Build Check)
```bash
npm run build
```

---

## 📖 Spesifikasi Endpoint Utama

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/health` | Server health check endpoint |
| `POST` | `/users/register-device` | Mendaftarkan/memperbarui token FCM & lokasi rumah perangkat |
| `POST` | `/users/update-location` | Memperbarui lokasi GPS aktif perangkat & menghitung $V_{s30}$ |
| `POST` | `/alerts/trigger-poll` | Memicu polling manual BMKG EWS untuk simulasi |
| `POST` | `/alerts/simulate` | Meluncurkan gempa simulasi dengan parameter tertentu |
| `GET` | `/alerts/latest` | Mengambil data alert gempa bumi terbaru |

---

## 🐳 Deployment (Hugging Face Spaces)

Backend ini di-deploy secara otomatis ke **Hugging Face Spaces** berbasis Docker SDK:
- **Live Base URL:** `https://lintangnv-suar-backend.hf.space`
- **Live Swagger Docs:** `https://lintangnv-suar-backend.hf.space/api/docs`
