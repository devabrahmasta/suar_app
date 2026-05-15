<div align="center">
  
  # 🚨 SUAR (Sistem Peringatan Dini & Evakuasi Bencana)
  
  **Aplikasi mitigasi bencana *offline-first* dengan integrasi AI Triage, rute evakuasi cerdas, pemantauan latar belakang, dan komunikasi Mesh (P2P).**

  ![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
  ![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
  ![Riverpod](https://img.shields.io/badge/Riverpod-blue?style=for-the-badge)
  ![Gemini AI](https://img.shields.io/badge/Gemini%20AI-Flash%201.5-orange?style=for-the-badge)
  ![Workmanager](https://img.shields.io/badge/Background-Workmanager-brightgreen?style=for-the-badge)

  <br>

  ### 📥 [Unduh Aplikasi (APK) - Rilis Terbaru](https://drive.google.com/drive/folders/1NNJlm1PrmNcebeoa7-MFdydZu_QjBkW9?usp=sharing)
  *(Klik tautan di atas untuk mengunduh versi rilis Android dari SUAR)*

</div>

---

## 📖 Tentang SUAR

**SUAR** hadir untuk menjembatani titik kritis antara terjadinya bencana alam (gempa bumi & tsunami) dengan tindakan penyelamatan diri. Ketika infrastruktur telekomunikasi lumpuh pasca-bencana, SUAR tetap beroperasi sebagai "kompas penyelamat" berkat arsitektur *Offline-First* yang tangguh.

Aplikasi ini menggabungkan data seismik waktu-nyata, analisis spasial risiko bencana, dan Kecerdasan Buatan (AI) untuk memberikan instruksi keselamatan yang dipersonalisasi sesuai lokasi presisi pengguna, bahkan berjalan aktif di latar belakang perangkat.

## ✨ Fitur Utama

### 🧠 1. AI Triage EWS (Early Warning System)
Menarik data gempa bumi langsung dari **BMKG** dan menganalisis posisi pengguna terhadap peta risiko tsunami **InaRISK BNPB**. Mesin **Google Gemini 1.5 Flash** kemudian menghasilkan keputusan *Triage* (Evakuasi vs. Berlindung) dan panduan darurat secara instan.

### 🗺️ 2. Smart Offline Evacuation (Hybrid Snapping)
Sistem pemetaan yang revolusioner untuk evakuasi tanpa internet:
* **Geofence Caching:** Otomatis mengunduh peta (*map tiles*) radius 3KM di latar belakang saat pengguna terdeteksi memasuki Zona Merah InaRISK.
* **Hybrid Routing Algorithm:** Mencari dataran tinggi terdekat (>5 meter) yang aman dari tsunami menggunakan algoritma 8-arah mata angin, memvalidasi elevasi via OpenRouteService (ORS), dan men-*snap* rute ke jalur khusus pejalan kaki (`foot-walking`).
* **Offline Fallback:** Menyimpan rute evakuasi ke memori internal (`SharedPreferences`) untuk langsung ditampilkan saat koneksi terputus.

### 🔔 3. Sistem Pemantauan Latar Belakang (Background Monitoring)
SUAR tidak pernah tidur. Menggunakan `Workmanager` dan isolasi Dart latar belakang, aplikasi akan secara periodik mengecek peringatan gempa terkini dari BMKG dan memberikan **Notifikasi Lokal** (*push notification*) yang interaktif seketika ada ancaman di sekitar pengguna.

### 📡 4. Mesh Network Chat *(Akan diimplementasikan di masa depan)*
*Status: Planned / Dalam Perencanaan*
* Komunikasi P2P (*Peer-to-Peer*) menggunakan modul Bluetooth/Wi-Fi Direct.
* *Public Channel* untuk broadcast darurat dan *Direct Message* untuk mencari anggota keluarga tanpa memerlukan sinyal BTS/Internet sama sekali.

---

## 🏗️ Arsitektur & Tech Stack

Proyek ini dibangun dengan standar industri dan mengikuti prinsip **Clean Architecture** (Feature-First) untuk menjaga skalabilitas kode.

* **Framework:** Flutter (SDK ^3.10.0 atau lebih baru)
* **State Management:** Riverpod 2.x (`flutter_riverpod`)
* **Routing:** GoRouter (Declarative Routing)
* **Maps & GIS:** 
    * `flutter_map` & `latlong2`
    * `flutter_map_tile_caching` (FMTC ObjectBox Backend)
    * OpenRouteService (Directions, Snap, & Elevation API)
* **AI Integration:** `google_generative_ai` (Gemini)
* **Background Tasks:** `workmanager`, `flutter_local_notifications`
* **Network & Hardware:** `dio`, `geolocator`, `connectivity_plus`

---

## 🚀 Memulai (Getting Started)

### Prasyarat
Pastikan lingkungan pengembangan Anda sudah siap:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) 
* Android Studio / VS Code
* Git

### Instalasi

1. **Kloning Repository**
   ```bash
   git clone https://github.com/username-anda/suar_app.git
   cd suar_app
   ```

2. **Unduh Dependencies**
   ```bash
   flutter pub get
   ```

3. **Pengaturan Environment Variables (.env)**
   Buat sebuah file bernama `.env` di direktori root (sejajar dengan `pubspec.yaml`) dan masukkan API Key Anda:
   ```env
   GEMINI_API_KEY=masukkan_api_key_google_gemini_anda_di_sini
   ORS_API_KEY=masukkan_api_key_open_route_service_anda_di_sini
   ```

4. **Jalankan Aplikasi**
   Sebaiknya jalankan pada *real device* (perangkat asli) untuk pengujian GPS dan Background Service yang akurat.
   ```bash
   flutter run
   ```

---

## 📂 Struktur Direktori

Proyek ini menggunakan arsitektur berbasis fitur (*Feature-First Architecture*):

```text
lib/
├── core/
│   ├── router/           # Konfigurasi GoRouter (Navigasi deklaratif)
│   ├── services/         # Layanan inti (Background Service, Notifications)
│   └── theme/            # Desain sistem, warna, dan tipografi UI
├── features/
│   ├── ews_ai/           # Integrasi BMKG, InaRISK, dan Gemini AI Triage
│   ├── map_evacuation/   # Sistem Peta, Hybrid Snapping, dan Caching Offline
│   ├── offline_mesh_chat/# [Akan Datang] Komunikasi P2P / Mesh
│   ├── onboarding/       # Izin akses perangkat & perkenalan aplikasi
│   ├── resources/        # Manajemen data aset/panduan siaga
│   └── user/             # Profil pengguna dan pengaturan
└── main.dart             # Entry point utama aplikasi
```

---

## 🛠️ Panel Developer (Skenario Pengujian)

Untuk mempermudah presentasi atau pengujian tanpa harus menunggu bencana asli terjadi, SUAR dilengkapi dengan **EWS Simulator**.
Akses fitur ini melalui ikon 🐛 (*Bug*) di AppBar Home Screen untuk menjalankan:

- Simulasi Gempa Tsunami + Masuk Zona Merah (InaRISK).
- Simulasi Gempa Ringan Darat.
- Simulasi pengunduhan Map Cache dan rute offline secara paksa.
- Uji coba Local Notification dan Background Trigger.

---

## 🤝 Kontribusi

Kami menyambut segala bentuk kontribusi! Jika Anda ingin berkontribusi pada proyek ini:
1. Lakukan *Fork* pada repository ini.
2. Buat *branch* fitur Anda (`git checkout -b feature/FiturKerenAnda`).
3. Lakukan *Commit* perubahan Anda (`git commit -m 'Menambahkan FiturKerenAnda'`).
4. *Push* ke branch tersebut (`git push origin feature/FiturKerenAnda`).
5. Buka sebuah *Pull Request*.

## 📄 Lisensi

Didistribusikan di bawah Lisensi MIT. Lihat `LICENSE` untuk informasi lebih lanjut.

<br>

<div align="center">
<i>Dibuat dengan dedikasi untuk memperkuat resiliensi masyarakat Indonesia dalam menghadapi bencana alam.</i>
</div>