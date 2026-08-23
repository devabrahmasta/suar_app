# 📱 SUAR Mobile App (Flutter Client)

> **Offline-First Disaster Mitigation Mobile Application with AI Emergency Triage, OpenQuake Shakemap Contour Visualizer, and Smart Offline Navigation.**

[![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-%230175C2.svg?style=for-the-badge&logo=Dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-blue?style=for-the-badge)](https://riverpod.dev)
[![GoRouter](https://img.shields.io/badge/GoRouter-17.x-green?style=for-the-badge)](https://pub.dev/packages/go_router)
[![Gemini AI](https://img.shields.io/badge/Gemini%20AI-Flash%201.5-orange?style=for-the-badge)](https://deepmind.google/technologies/gemini/)

---

## 📖 Overview

Aplikasi **SUAR Mobile** didesain khusus untuk situasi darurat bencana alam (gempa bumi & tsunami) ketika jaringan telekomunikasi seluler dan internet berisiko lumpuh total. Aplikasi ini bekerja dengan prinsip **Offline-First**, mengunduh peta dan rute evakuasi secara otomatis sebelum sinyal hilang.

---

## ✨ Fitur Utama Client

### 🧠 1. AI Triage & EWS Early Warning System
- **Real-Time Alert & FCM Listening:** Menerima notifikasi darurat dari backend SUAR saat gempa berpotensi bahaya terjadi.
- **Google Gemini 1.5 Flash AI Triage:** Menganalisis parameter gempa, posisi GPS pengguna, dan data risiko InaRISK untuk menghasilkan rekomendasi tindakan (*Evakuasi vs. Berlindung di Tempat*) beserta panduan keselamatan yang dipersonalisasi.
- **Rule-Based BNPB Fallback:** Mengaktifkan mesin penilai risiko lokal berbasis pedoman BNPB jika internet terputus sebelum analisis AI selesai.

### 🗺️ 2. OpenQuake Shakemap Contour Visualizer
- **Visualisasi Kontur Intensitas Guncangan (MMI):** Menampilkan peta gradasi kontur lingkaran/poligon konsentris yang merepresentasikan zona dampak intensitas gempa secara real-time:
  - 🔴 **Zona Merah ($\text{MMI} \ge \text{VII}$):** Guncangan sangat kuat, potensi kerusakan struktur tinggi.
  - 🟠 **Zona Oranye ($\text{MMI V–VI}$):** Guncangan kuat, alarm sirene berbunyi aktif di HP.
  - 🟢 **Zona Hijau ($\text{MMI III–IV}$):** Guncangan ringan/terasa, zona kewaspadaan.
- **Simulator Gempa Interaktif:** Pengguna dapat mengetuk titik mana saja pada peta untuk memindahkan episentrum simulasi dan secara langsung melihat kalkulasi status jarak (*DI DALAM vs DI LUAR radius*).

### 📍 3. Smart Offline Evacuation (Hybrid Snapping & JIT Caching)
- **Just-In-Time (JIT) Geofence Tile Caching:** Otomatis mengunduh berkas peta (*map tiles*) radius 3–5 KM melalui `flutter_map_tile_caching` (FMTC) di latar belakang saat memasuki zona risiko InaRISK.
- **Hybrid Routing & Elevation Snapping:** Mencari dataran tinggi aman terdekat (>5 meter) menggunakan algoritma 8-arah mata angin, memverifikasi rute pejalan kaki dengan OpenRouteService (ORS), dan menyimpan rute secara lokal.
- **Navigasi GPS Luring:** Menampilkan peta luring, rute evakuasi, dan indikator posisi GPS satelit tanpa koneksi internet.

### 🔔 4. Background Monitoring & Safety Net
- **Background Polling:** Memantau aktivitas seismik BMKG di latar belakang via `workmanager` dan Dart isolation.
- **Foreground Service:** Menjaga aplikasi tetap aktif di memori Android saat situasi darurat.

---

## 🏗️ Arsitektur Aplikasi & Struktur Kode

Aplikasi ini menggunakan pola **Clean Architecture** berbasis fitur (*Feature-First*):

```
frontend/lib/
├── core/                        # Modul Inti & Konfigurasi Global
│   ├── router/                  # Konfigurasi deklaratif GoRouter (app_router.dart)
│   ├── services/                # Background service, notification service, location service
│   ├── theme/                   # Desain sistem, warna kontras tinggi, tema gelap/terang
│   └── utils/                   # Helper matematika geospasial & formatting
├── features/                    # Modul Berbasis Fitur (Feature-First)
│   ├── ews_ai/                  # Fitur deteksi EWS, AI Gemini Triage, & Interactive Simulator (OpenQuake Shakemap)
│   ├── map_evacuation/          # Peta luring, FMTC tile cache, ORS routing, & Navigasi GPS
│   ├── onboarding/              # Flow izin akses (GPS, Bluetooth, Battery Optimization)
│   ├── resources/               # Panduan tanggap bencana luring & kontak darurat
│   └── user/                    # Profil pengguna & Developer Debug Panel
├── shared/                      # Reusable widgets (Custom Buttons, Cards, Dialogs)
└── main.dart                    # Entry point inisialisasi aplikasi
```

---

## 🛠️ Teknologi & Dependensi Utama

- **Framework:** Flutter SDK `^3.10.4`
- **Language:** Dart SDK `^3.0.0`
- **State Management:** `flutter_riverpod` (v3.x)
- **Routing & Navigation:** `go_router` (v17.x)
- **Map & Spatial GIS:**
  - `flutter_map` (v7.x) — Rendering peta interaktif
  - `flutter_map_tile_caching` (FMTC) — Storage map tiles luring SQLite
  - `latlong2` & `geolocator` — Kalkulasi posisi geospasial & GPS satelit
- **AI & Networking:** `google_generative_ai` (Gemini 1.5 Flash) & `dio`
- **Background Task:** `workmanager` & `flutter_local_notifications`

---

## 🚀 Panduan Memulai (Getting Started)

### 1. Prasyarat
- Flutter SDK (`>= 3.10.4`).
- Android Studio / VS Code dengan ekstensi Flutter & Dart.
- Perangkat Android fisik (*real device*) untuk pengujian GPS, Bluetooth, dan background task.

### 2. Instalasi Dependensi
```bash
cd frontend
flutter pub get
```

### 3. Konfigurasi Environment Variables (`.env`)
Buat berkas `.env` di dalam direktori `frontend/`:

```env
GEMINI_API_KEY=masukkan_api_key_google_gemini_anda
ORS_API_KEY=masukkan_api_key_openrouteservice_anda
BACKEND_URL=https://lintangnv-suar-backend.hf.space
```

### 4. Menjalankan Aplikasi
```bash
flutter run
```

---

## 🧪 Pengujian & Verifikasi

### Static Code Analysis
```bash
flutter analyze
```

### Unit Testing
```bash
flutter test
```

### Build Android APK
```bash
flutter build apk --release
```
Berkas APK hasil kompilasi akan tersimpan di `build/app/outputs/flutter-apk/app-release.apk`.
