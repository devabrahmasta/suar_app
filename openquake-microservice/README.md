# ⚡ SUAR OpenQuake Hazard Microservice

> **Stateless Python FastAPI Microservice for High-Precision Seismic Ground Motion Prediction Equations (GMPE) & Soil Amplification Calculation.**

---

## 📖 Overview

Microservice ini dikembangkan menggunakan **FastAPI** dan engine standardisasi internasional **OpenQuake (`openquake.engine`)** dari *GEM (Global Earthquake Model) Foundation*. Services ini bertindak sebagai kalkulator spasial seismik *stateless* yang menerima parameter gempa bumi dan lokasi perangkat pengguna dari backend NestJS, lalu menghitung estimasi percepatan tanah puncak (**PGA**) serta skala intensitas guncangan (**MMI**) secara real-time.

---

## ✨ Fitur Utama

- **Klasifikasi Wilayah Tektonik Spasial (Slab2 Boundary):**
  - **Shallow Crustal (Kerak Dangkal):** Menggunakan model GMPE `BooreEtAl2014`.
  - **Subduction Interface (Subduksi Antar-Lempeng):** Menggunakan model GMPE `AbrahamsonEtAl2015SInter`.
  - **Subduction Intraslab (Subduksi Dalam-Lempeng):** Menggunakan model GMPE `AbrahamsonEtAl2015SSlab`.
  - Klasifikasi berbasis boundary kedalaman Slab2 dan ketidakpastian ($\pm 2\sigma$), dengan fallback otomatis ke kriteria kedalaman statis (<30 km, 30–60 km, >60 km).
- **Konversi Skala Intensitas Wald et al. (1999):**
  - Mengonversi PGA hasil OpenQuake (dalam satuan $g$) ke Gal ($cm/s^2$) dengan mengalikan $980.665$.
  - Menghitung MMI menggunakan rumus:
    $$\text{MMI} = 3.66 \log_{10}(\text{PGA}_{\text{gal}}) - 1.66$$
  - Hasil MMI diklipping ke rentang valid $[1.0, 12.0]$.
- **Penguat Situs Tanah ($V_{s30}$ Soil Amplification):**
  - Memperhitungkan efek amplifikasi tanah lokal berdasarkan nilai $V_{s30}$ (kecepatan gelombang geser 30 meter teratas) masing-masing lokasi pengguna.
- **Keamanan & Autentikasi API Key:**
  - Endpoint sensitif dilindungi header HTTP `X-API-Key` yang disinkronkan dengan environment variable `OPENQUAKE_API_KEY`.
- **Keep-Alive Endpoint:**
  - Endpoint `GET /health` ringan tanpa autentikasi untuk memitigasi *cold-start* (misalnya dari Hugging Face Space yang tertidur).

---

## 🛠️ Teknologi yang Digunakan

- **Python:** 3.10+
- **Framework:** FastAPI & Uvicorn (ASGI Web Server)
- **Seismic Engine:** `openquake.engine` (OpenQuake Hazard Library)
- **Data & Math:** NumPy, Fiona, Rasterio, Affine
- **Validation:** Pydantic v2

---

## 📁 Struktur Direktori

```
openquake-microservice/
├── app.py                  # Entry point utama FastAPI application
├── requirements.txt        # Daftar dependensi Python
├── tiff_to_points.py       # Converter GeoTIFF raster ke Point Grid SQL (Option B Fallback)
└── verify_db_setup.py      # Diagnostic script pengujian koneksi database Supabase PostGIS
```

---

## 🚀 Panduan Memulai (Getting Started)

### 1. Prasyarat
- Python `3.10` atau versi lebih baru.
- Virtual Environment (`venv`).

### 2. Instalasi & Menjalankan Lokal

```bash
# 1. Pindah ke direktori microservice
cd openquake-microservice

# 2. Buat virtual environment
python -m venv venv

# 3. Aktifkan virtual environment
# Windows:
venv\Scripts\activate
# Linux/macOS:
source venv/bin/activate

# 4. Instal dependensi
pip install -r requirements.txt

# 5. Jalankan server FastAPI dengan Uvicorn
uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```

---

## 📖 Spesifikasi API Endpoints

### 1. Health Check (Keep-Alive)
- **URL:** `GET /health`
- **Autentikasi:** Tidak Ada (Publik)
- **Response Contoh (200 OK):**
  ```json
  {
    "status": "ok",
    "message": "SUAR OpenQuake microservice is running"
  }
  ```

### 2. Hitung Bahaya Seismik (Calculate Hazard)
- **URL:** `POST /calculate-hazard`
- **Headers Required:**
  - `Content-Type: application/json`
  - `X-API-Key: suar_secret_key_123` (atau sesuai `OPENQUAKE_API_KEY`)
- **Request Body Contoh:**
  ```json
  {
    "eq_params": {
      "magnitude": 6.5,
      "depth": 25.0,
      "latitude": -7.79,
      "longitude": 110.36,
      "wilayah": "Yogyakarta",
      "potensi": "Tidak berpotensi tsunami",
      "slab2_depth": -35.5,
      "slab2_unc": 12.0
    },
    "users": [
      {
        "deviceId": "user_device_001",
        "latitude": -7.79,
        "longitude": 110.36,
        "vs30": 270.0
      },
      {
        "deviceId": "user_device_002",
        "latitude": -7.89,
        "longitude": 110.45,
        "vs30": 450.0
      }
    ]
  }
  ```
- **Response Contoh (200 OK):**
  ```json
  [
    {
      "deviceId": "user_device_001",
      "pga": 0.2451,
      "mmi": 7.26
    },
    {
      "deviceId": "user_device_002",
      "pga": 0.1823,
      "mmi": 6.74
    }
  ]
  ```

---

## 🛠️ Skrip Utilitas & Diagnostik

### 1. Verifikasi Koneksi & Setup Database (`verify_db_setup.py`)
Mengecek kestabilan koneksi PostgreSQL Supabase, keberadaan ekstensi PostGIS, tabel raster (`vs30_soil_raster`, `slab2_depth_raster`), dan tabel point grid (`vs30_soil_points`, `slab2_points`).

```bash
python verify_db_setup.py "postgresql://user:password@host:5432/database"
```

### 2. Konversi GeoTIFF ke Point Grid SQL (`tiff_to_points.py`)
Mengonversi berkas GeoTIFF $V_{s30}$ atau Slab2 menjadi skrip SQL `INSERT` untuk pengujian *KNN spatial index operator* (`<->`) di PostgreSQL jika fitur raster dibatasi.

```bash
python tiff_to_points.py vs30_indonesia.tif vs30_soil_points vs30_insert.sql 10
```
