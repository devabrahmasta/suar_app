<div align="center">
  <img src="frontend/assets/images/suar_logo.png" alt="SUAR Logo" width="120" style="border-radius: 24px; margin-bottom: 16px;"/>

  # 🚨 SUAR Monorepo Ecosystem
  ### *Tetap Menyala Saat Segalanya Padam*

  **Aplikasi Mitigasi Bencana *Offline-First* dengan Integrasi Pemodelan Bahaya Seismik OpenQuake GMPE, Amplifikasi Tanah Vs30, AI Triage, Rute Evakuasi Cerdas, Pemantauan Latar Belakang, dan Komunikasi P2P Mesh Network.**

  [![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.0%2B-%230175C2.svg?style=for-the-badge&logo=Dart&logoColor=white)](https://dart.dev)
  [![NestJS](https://img.shields.io/badge/NestJS-10.x-E0234E?style=for-the-badge&logo=nestjs&logoColor=white)](https://nestjs.com)
  [![FastAPI](https://img.shields.io/badge/FastAPI-0.100%2B-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
  [![OpenQuake](https://img.shields.io/badge/OpenQuake-Engine-orange?style=for-the-badge)](https://www.globalquakemodel.org)
  [![PostGIS](https://img.shields.io/badge/PostGIS-Spatial_DB-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgis.net)
  [![Gemini AI](https://img.shields.io/badge/Gemini%20AI-Flash%201.5-orange?style=for-the-badge)](https://deepmind.google/technologies/gemini/)
  [![Platform](https://img.shields.io/badge/Platform-Android-green?style=for-the-badge&logo=android)](https://www.android.com)

  ---

  ### 📥 [Unduh Aplikasi (APK) - Rilis Terbaru](https://drive.google.com/drive/folders/1NNJlm1PrmNcebeoa7-MFdydZu_QjBkW9?usp=sharing)
  *(Klik tautan di atas untuk mengunduh versi rilis Android stabil dari SUAR)*

</div>

---

## 📖 Daftar Isi
1. [Tentang SUAR](#-tentang-suar)
2. [Fitur Utama Sistem](#-fitur-utama-sistem)
3. [Arsitektur Monorepo & Alur Data](#-arsitektur-monorepo--alur-data)
4. [Teknologi yang Digunakan (Tech Stack)](#-teknologi-yang-digunakan-tech-stack)
5. [Struktur Direktori Monorepo](#-struktur-diretori-monorepo)
6. [Panduan Memulai (Getting Started)](#-panduan-memulai-getting-started)
   - [Prasyarat](#prasyarat)
   - [1. Menjalankan Python OpenQuake Microservice](#1-menjalankan-python-openquake-microservice)
   - [2. Menjalankan NestJS Backend & Database](#2-menjalankan-nestjs-backend--database)
   - [3. Menjalankan Aplikasi Flutter (Client)](#3-menjalankan-aplikasi-flutter-client)
   - [4. Skrip Verifikasi Database Supabase](#4-skrip-verifikasi-database-supabase)
7. [Dokumentasi API Interaktif & Keamanan](#-dokumentasi-api-interaktif--keamanan)
8. [Panel Developer & Simulasi Pengujian](#-panel-developer--simulasi-pengujian)
9. [Tim & Kontributor](#-tim--kontributor)
10. [Apresiasi & Lisensi](#-apresiasi--lisensi)

---

## 📖 Tentang SUAR

**SUAR** dirancang untuk menjembatani titik kritis antara terjadinya bencana alam (terutama gempa bumi & tsunami) dengan tindakan penyelamatan diri. Ketika bencana skala besar melanda, infrastruktur telekomunikasi seluler dan internet sering kali lumpuh total, memicu disorientasi massal dan memutus jalur komunikasi penyelamatan. 

SUAR hadir sebagai solusi tangguh berbasis **Offline-First** yang didukung pemodelan seismik fisik presisi tinggi:
- **EWS Seismik Presisi Tinggi (OpenQuake Integration):** Menghitung percepatan tanah puncak (**PGA**) dan skala intensitas guncangan (**MMI**) berdasarkan standar *GEM (Global Earthquake Model) Foundation*, memperhitungkan klasifikasi tektonik Slab2 dan amplifikasi tanah $V_{s30}$.
- **Navigasi Evakuasi Luring:** Menggabungkan data BMKG secara real-time, analisis spasial peta risiko InaRISK BNPB, dan pemrosesan AI untuk mengunduh peta serta rute evakuasi secara otomatis sebelum sinyal hilang.
- **Mesh Network Chat:** Ketika internet mati sepenuhnya, fitur komunikasi berbasis jaringan peer-to-peer (P2P Mesh Network via Bluetooth & Wi-Fi Direct) tetap dapat digunakan untuk menghubungkan korban di daerah terdampak.

Aplikasi ini dikembangkan untuk ajang **IDCamp Dicoding Challenge 2026** di bawah tema *"Small Apps for Big Preparedness"*. Seluruh kebutuhan pengembangan telah didokumentasikan pada berkas [SUAR_PRD.md](./SUAR_PRD.md).

---

## ✨ Fitur Utama Sistem

### ⚡ 1. Pemodelan Bahaya Seismik OpenQuake & Amplifikasi Tanah $V_{s30}$ (Phase 3 EWS)
* **Klasifikasi Tektonik Spasial (Slab2 Boundary):** Mengklasifikasikan sumber gempa bumi secara otomatis berdasarkan kedalaman Slab2 dan batas ketidakpastian ($\pm 2\sigma$):
  * **Active Shallow Crustal:** Menggunakan GMPE `BooreEtAl2014`.
  * **Subduction Interface:** Menggunakan GMPE `AbrahamsonEtAl2015SInter`.
  * **Subduction Intraslab:** Menggunakan GMPE `AbrahamsonEtAl2015SSlab`.
* **Kalkulasi Amplifikasi Tanah Situs ($V_{s30}$):** Memperhitungkan efek jenis tanah lokal berbasis data kecepatan gelombang geser 30m teratas ($V_{s30}$) dari raster spasial PostGIS `vs30_soil_raster` (`SELECT ST_Value(rast, ST_SetSRID(ST_Point(lon, lat), 4326))`).
* **Kueri Spasial Subduksi Slab2:** Mengambil kedalaman subduksi (`slab2_depth_raster`) dan ketidakpastian (`slab2_unc_raster`) di titik episenter secara langsung dari Supabase PostGIS untuk menentukan geometri lempeng subduksi.
* **Konversi MMI (Wald et al. 1999):** Mengonversi PGA ($g$) ke Gal ($cm/s^2$) lalu menghitung MMI dengan rumus:
  $$\text{MMI} = 3.66 \log_{10}(\text{PGA}_{\text{gal}}) - 1.66$$
* **Penyaringan Alarm Darurat & Fallback:** Mengirim notifikasi darurat FCM hanya jika $\text{MMI} \ge \text{V}$, serta menyediakan mekanisme *Phase 2 Dynamic Radius Fallback* jika microservice tidak terjangkau.

### 🧠 2. AI Triage EWS (Early Warning System)
* **BMKG Real-Time Integration:** Memantau data gempa bumi langsung dari API BMKG setiap 30 detik.
* **Google Gemini AI Flash Triage:** Menghasilkan keputusan *Triage* darurat secara cerdas (Evakuasi vs. Berlindung di Tempat) beserta instruksi keselamatan yang dipersonalisasi sesuai profil lokasi pengguna.
* **Offline Advisor Fallback:** Mengaktifkan algoritma penilai risiko berbasis aturan BNPB lokal jika koneksi internet terputus.

### 🗺️ 3. Visualisasi Shakemap Kontur & Navigasi Evakuasi Luring
* **Shakemap Contour Visualizer:** Menampilkan visualisasi kontur gradasi warna konsentris pada peta interaktif Flutter untuk representasi zona intensitas guncangan MMI (🔴 MMI $\ge$ VII, 🟠 MMI V–VI, 🟢 MMI III–IV).
* **Just-In-Time (JIT) Geofence Caching:** Otomatis mengunduh berkas peta (*map tiles*) radius 3–5 KM melalui `flutter_map_tile_caching` (FMTC) di latar belakang saat memasuki Zona Merah InaRISK.
* **Hybrid Routing & Elevation Snapping:** Menentukan dataran tinggi aman terdekat (>5 meter) menggunakan algoritma 8-arah mata angin dan rute pejalan kaki OpenRouteService (ORS).

### 🔔 4. Pemantauan Latar Belakang & Mitigasi Cold-Start
* **Background Polling:** Menggunakan `Workmanager` dan isolasi latar belakang Dart untuk terus mengamati aktivitas seismik BMKG saat aplikasi ditutup.
* **Foreground Service Safety Net:** Mendaftarkan layanan mitigasi di status bar Android untuk mencegah *app kill*.
* **Automated Keep-Alive Ping:** Backend NestJS memicu ping otomatis ke endpoint `/health` milik microservice untuk menjaga Hugging Face Space tetap aktif.

### 📡 5. Jaringan Obrolan Mesh P2P (Offline Mesh Chat)
* **Auto-Discovery:** Memindai dan menghubungkan perangkat terdekat yang menginstal SUAR secara otomatis via Bluetooth & Wi-Fi Direct (`nearby_connections`).
* **Multi-Hop Relay:** Pesan chat dikirimkan melalui jalur estafet antar-HP (hingga 5 hop) untuk menjangkau area di luar jangkauan sinyal Bluetooth langsung.
* **Public & Private Channels:** Channel publik untuk siaran darurat massal dan chat privat 1-on-1.

---

## 📐 Arsitektur Monorepo & Alur Data

SUAR dibangun dengan pendekatan **Monorepo** yang memisahkan tanggung jawab antara *Mobile Client (Flutter)*, *Cloud Backend (NestJS)*, *Database Spasial (PostGIS/Supabase)*, dan *Seismic Hazard Calculator (FastAPI + OpenQuake)*:

```mermaid
flowchart TD
    subgraph ClientLayer[Mobile App - Flutter]
        UI[EWS Interactive Simulator UI]
        MapVis[Shakemap Contour Visualizer MMI]
        Nav[Offline Navigation & FMTC Cache]
        Mesh[P2P Mesh Network Chat]
    end

    subgraph BackendLayer[Cloud Server - NestJS]
        Poller[BMKG EWS Poller]
        Dedup[SHA-256 Alert Deduplicator]
        AlertSvc[Alerts Service]
        UserSvc[Users Service & Vs30 Lookup]
    end

    subgraph MicroserviceLayer[Python Microservice - FastAPI]
        OQEngine[OpenQuake Hazard Engine]
        SlabClassifier[Slab2 Tectonic Classifier]
        GMPE[Boore / Abrahamson GMPE Models]
        Wald[Wald 1999 MMI Converter]
    end

    subgraph DBLayer[Database Spasial - PostgreSQL / PostGIS Supabase]
        UserDev[(user_devices Table)]
        Vs30Raster[(vs30_soil_raster / vs30_soil_points)]
        SlabRaster[(slab2_depth_raster & slab2_unc_raster)]
    end

    Poller -->|Fetch BMKG API| Dedup
    Dedup -->|Process Alert| AlertSvc
    AlertSvc -->|ST_Value / KNN Lookup| SlabRaster
    UserSvc -->|ST_Value / KNN Lookup| Vs30Raster
    AlertSvc -->|POST /calculate-hazard X-API-Key| SlabClassifier
    SlabClassifier --> GMPE --> Wald --> OQEngine
    OQEngine -->|Return PGA & MMI Array| AlertSvc
    AlertSvc -->|Filter MMI >= V & Send FCM| UI
    UI --> MapVis
    UI --> Nav
```

---

## 🏗️ Teknologi yang Digunakan (Tech Stack)

| Komponen | Teknologi / Library Utama | Fungsi Utama |
|---|---|---|
| **Mobile Frontend** | Flutter 3.10+, Dart 3.0+, Riverpod 3.x, GoRouter 17.x | UI/UX, State Management, Navigasi Deklaratif |
| **Map & Navigation** | `flutter_map`, `flutter_map_tile_caching` (FMTC), `latlong2` | Rendering Peta Interaktif, Tile Caching Luring, Geospasial |
| **Mesh Network** | `nearby_connections` | Bluetooth & Wi-Fi Direct P2P Mesh Communication |
| **AI Integration** | `google_generative_ai` (Gemini 1.5 Flash) | Triage Rekomendasi Keselamatan Darurat |
| **Cloud Backend** | NestJS 10.x, TypeORM, Swagger UI, Firebase Admin | Cloud Server EWS, FCM Dispatch, API Gateway |
| **Spatial Database** | PostgreSQL + PostGIS Extension (Supabase / Docker) | Penyimpanan Koordinat, Spatial Queries (`ST_DWithin`, `ST_Value`, KNN `<->`) |
| **Seismic Microservice** | FastAPI, Uvicorn, OpenQuake Engine (`openquake.engine`) | GMPE Seismic Hazard Calculation, Wald 1999 MMI Conversion |
| **Data Processing** | NumPy, Fiona, Rasterio, Python 3.10+ | Raster Processing, Matrix Math, GeoTIFF Parsing |

---

## 📂 Struktur Direktori Monorepo

- 📱 **[frontend/](./frontend)** — Aplikasi Mobile Client berbasis Flutter & Dart ([README Frontend](./frontend/README.md))
  - `lib/core/` — Router, theme, notification, & background services
  - `lib/features/ews_ai/` — Deteksi EWS, Gemini AI, & OpenQuake Shakemap Simulator
  - `lib/features/map_evacuation/` — Peta luring FMTC cache & ORS routing
  - `lib/features/offline_mesh_chat/` — Komunikasi P2P Mesh Network
  - `lib/features/user/` — Profil & Panel Developer Debug Simulator
- 🔔 **[backend/](./backend)** — Cloud Backend Server berbasis NestJS & TypeORM ([README Backend](./backend/README.md))
  - `src/alerts/` — EWS Polling BMKG, Slab2 lookup, OpenQuake REST call, FCM Push
  - `src/users/` — Pendaftaran perangkat, lokasi aktif, & vs30 raster lookup
  - `Dockerfile` — Konfigurasi containerization untuk Hugging Face Spaces
- ⚡ **[openquake-microservice/](./openquake-microservice)** — Python FastAPI Microservice ([README Microservice](./openquake-microservice/README.md))
  - `app.py` — Application entry point (`GET /health`, `POST /calculate-hazard`)
  - `requirements.txt` — Dependensi Python (OpenQuake engine, FastAPI, Rasterio)
  - `verify_db_setup.py` — Script diagnostik pengujian PostGIS Supabase
  - `tiff_to_points.py` — Converter GeoTIFF raster ke Point Grid SQL

---

## 🚀 Panduan Memulai (Getting Started)

### Prasyarat
- **Flutter SDK** versi `^3.10.4` ke atas.
- **Node.js** versi `^18.0.0` atau `^20.0.0`.
- **Python** versi `^3.10.0` ke atas.
- **Docker** & **Docker Compose** (atau database PostgreSQL + PostGIS di Supabase).

---

### 1. Menjalankan Python OpenQuake Microservice

```bash
cd openquake-microservice
python -m venv venv

# Activate venv (Windows):
venv\Scripts\activate
# Activate venv (Linux/macOS):
# source venv/bin/activate

pip install -r requirements.txt
uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```
Microservice akan aktif pada `http://127.0.0.1:8000`.

---

### 2. Menjalankan NestJS Backend & Database

```bash
cd backend
npm install

# Jalankan PostGIS via Docker (jika tidak menggunakan Supabase):
docker compose up -d

# Buat berkas .env dan atur kredensial:
cp .env.example .env

# Jalankan server development:
npm run start:dev

# Jalankan unit test otomatis:
npm run test
```
Server NestJS Backend akan aktif pada `http://localhost:3000`.

---

### 3. Menjalankan Aplikasi Flutter (Client)

```bash
cd frontend
flutter pub get

# Buat berkas .env di dalam folder frontend/
# Isi dengan GEMINI_API_KEY, ORS_API_KEY, dan BACKEND_URL

# Jalankan di perangkat Android asli:
flutter run
```

---

### 4. Skrip Verifikasi Database Supabase

Untuk memverifikasi koneksi database Supabase dan mengecek ekstensi PostGIS serta kueri raster / point grid:

```bash
cd openquake-microservice
python verify_db_setup.py "postgresql://postgres.xxx:password@aws-1-ap-southeast-2.pooler.supabase.com:5432/postgres"
```

---

## 📖 Dokumentasi API Interaktif & Keamanan

### Live Swagger UI
- **Dokumentasi API Produksi Backend:** [https://lintangnv-suar-backend.hf.space/api/docs](https://lintangnv-suar-backend.hf.space/api/docs)
- **Dokumentasi API Lokal Backend:** `http://localhost:3000/api/docs`

### Otentikasi Keamanan Antar-Service
Komunikasi antara backend NestJS dan Python OpenQuake Microservice dilindungi dengan header HTTP:
```http
X-API-Key: suar_secret_key_123
```
Nilai ini disinkronkan melalui variabel lingkungan `OPENQUAKE_API_KEY`.

---

## 🛠️ Panel Developer & Simulasi Pengujian

SUAR dilengkapi **EWS Interactive Simulator** yang dapat diakses melalui ikon kumbang (**Bug**) pada layar Profil Pengguna atau menu EWS AI:

- **Shakemap Contour Visualizer:** Melihat visualisasi zona dampak guncangan gempa (MMI $\ge$ VII, V–VI, III–IV) secara real-time.
- **Simulasi Episentrum Spasial:** Mengetuk peta untuk menggeser koordinat gempa dan menguji apakah lokasi pengguna berada *DI DALAM* atau *DI LUAR* radius bahaya.
- **Pengujian Sirene & FCM:** Menguji pengiriman notifikasi darurat sirene lokal maupun FCM push notification.

---

## 🤝 Tim & Kontributor

Proyek SUAR dirancang, dibangun, dan diselesaikan oleh tim berikut:

| Foto Kontributor | Nama Kontributor | Peran Utama | Deskripsi Tanggung Jawab |
|:---:|---|---|---|
| <img src="https://github.com/LintangNov.png" width="80" style="border-radius:50%"/> | **Waladi Lintang Novianto** | `Backend & Microservice Developer` | Bertanggung jawab atas pengembangan backend NestJS, integrasi Python OpenQuake Microservice (GMPE & Vs30), PostGIS spatial queries, polling BMKG, dan arsitektur P2P Mesh Network. |
| <img src="https://github.com/devabrahmasta.png" width="80" style="border-radius:50%"/> | **Pande Made Deva Brahmasta** | `Frontend & Mobile Developer` | Bertanggung jawab atas perancangan state management (Riverpod), navigasi GoRouter, rendering peta offline FMTC, OpenQuake Shakemap Contour Visualizer, integrasi Google Gemini AI, dan EWS Simulator. |
| <img src="https://github.com/gracerianty.png" width="80" style="border-radius:50%"/> | **Grace Rianty Butar Butar** | `UI/UX Designer` | Bertanggung jawab atas riset kebutuhan korban bencana, pembuatan desain antarmuka ramah situasi darurat (*Panic-Friendly UI*), penyusunan skema warna kontras tinggi, dan pemodelan UX. |

---

## 📄 Apresiasi & Lisensi

Aplikasi ini dikembangkan sebagai proyek submisi untuk **IDCamp Dicoding Challenge 2026** di bawah kategori aplikasi mitigasi kebencanaan (*Small Apps for Big Preparedness*).

- **Kredit Sumber Data:** Data gempa bumi disediakan oleh **BMKG Open Data**. Analisis zona risiko didasarkan pada data **InaRISK BNPB**. Model tektonik didasarkan pada **USGS Slab2**. Engine seismik didukung oleh **OpenQuake (GEM Foundation)**. Peta dasar dilayani oleh kontributor **OpenStreetMap**.

<br>

<div align="center">
  <i>Dibuat dengan dedikasi untuk memperkuat kesiapsiagaan dan resiliensi masyarakat Indonesia dalam menghadapi bencana alam. 🇮🇩</i>
</div>
