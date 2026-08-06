# 🌊 Panduan Integrasi EWS Zona Merah Tsunami (Jawa & Bali) untuk Developer Frontend (Flutter)

Dokumen ini disusun sebagai panduan teknis resmi bagi **Developer Mobile Frontend (Flutter)** untuk mengintegrasikan fitur **Pengecekan Realtime Zona Merah Tsunami**, **Visualisasi Overlay Layer Peta**, dan **Tile Caching Luring (FMTC)** yang disediakan oleh backend NestJS + PostGIS.

---

## 📌 Ringkasan Capability Backend

Backend SUAR telah menyediakan 3 capability geospasial utama:

| Service / Capability | Endpoint Backend | Format Response | Kegunaan Utama |
| :--- | :--- | :--- | :--- |
| **Realtime Point-in-Polygon Check** | `GET /alerts/tsunami-check?latitude={lat}&longitude={lng}` | `JSON` | Deteksi apakah lokasi GPS aktif perangkat HP berada dalam Zona Merah Tsunami. |
| **Vector Tile Overlay (SVG/Image)** | `GET /alerts/tsunami-tile/{z}/{x}/{y}.svg` | `image/svg+xml` | Visualisasi ubin overlay peta transparan pada `flutter_map` saat online. |
| **Mapbox Vector Tile (MVT)** | `GET /alerts/tsunami-tile/{z}/{x}/{y}.pbf` | `application/x-protobuf` | Rendering ubin vektor resolusi tinggi jika menggunakan MapLibre/VectorTile plugin. |

---

## 1. Integrasi Pengecekan Status Realtime (Point-in-Polygon)

### A. Endpoint Spesifikasi
* **URL:** `GET /alerts/tsunami-check`
* **Query Parameters:**
  * `latitude` (double, required): Koordinat lintang pengguna (contoh: `-7.02`).
  * `longitude` (double, required): Koordinat bujur pengguna (contoh: `110.32`).

### B. Contoh Response JSON

#### Skenario 1: Lokasi di Pesisir (Zona Merah Tsunami)
```json
{
  "isRedZone": true,
  "hazardLevel": "HIGH",
  "location": {
    "latitude": -7.02,
    "longitude": 110.32
  }
}
```

#### Skenario 2: Lokasi di Daratan/Aman
```json
{
  "isRedZone": false,
  "hazardLevel": "SAFE",
  "location": {
    "latitude": -7.78,
    "longitude": 110.36
  }
}
```

### C. Panduan Implementasi di Flutter (`inarisk_service.dart`)

Perbarui fungsi `checkTsunamiHazard` pada `InaRiskService` agar mengutamakan backend SUAR dengan *fallback* otomatis ke InaRISK BNPB:

```dart
Future<bool> checkTsunamiHazard(double latitude, double longitude) async {
  try {
    // 1. Coba kueri ke Backend SUAR (PostGIS High Precision)
    final response = await _dio.get(
      'https://your-suar-backend.com/alerts/tsunami-check',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      },
      options: Options(receiveTimeout: const Duration(seconds: 4)),
    );

    if (response.statusCode == 200 && response.data != null) {
      return response.data['isRedZone'] == true;
    }
  } catch (e) {
    debugPrint('SUAR Backend Tsunami Check error, falling back to InaRISK: $e');
  }

  // 2. Fallback ke API Online InaRISK BNPB jika Backend SUAR Unreachable
  try {
    const url = 'https://gis.bnpb.go.id/server/rest/services/inarisk/tsunami_bahaya/MapServer/0/query';
    final response = await _dio.get(
      url,
      queryParameters: {
        'f': 'json',
        'geometryType': 'esriGeometryPoint',
        'geometry': '$longitude,$latitude',
        'inSR': '4326',
        'spatialRel': 'esriSpatialRelIntersects',
        'returnGeometry': 'false',
        'outFields': '*',
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      return data['features'] != null && (data['features'] as List).isNotEmpty;
    }
  } catch (e) {
    debugPrint('InaRISK Fallback Error: $e');
  }

  return false;
}
```

---

## 2. Integrasi Visualisasi Overlay Peta (`flutter_map`)

### A. Menambahkan Overlay Layer Tsunami di `map_screen.dart`

Anda dapat menambahkan `TileLayer` transparan khusus untuk zona merah tsunami di atas layer peta dasar OpenStreetMap:

```dart
Widget buildMap(BuildContext context, bool showTsunamiLayer) {
  return FlutterMap(
    options: MapOptions(
      initialCenter: LatLng(-7.79, 110.36),
      initialZoom: 13.0,
    ),
    children: [
      // 1. Layer Peta Dasar OpenStreetMap
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.suar.app',
        tileProvider: FMTCStore('evacuation_map').getTileProvider(),
      ),

      // 2. Overlay Layer Zona Merah Tsunami (SUAR Backend)
      if (showTsunamiLayer)
        TileLayer(
          urlTemplate: 'https://your-suar-backend.com/alerts/tsunami-tile/{z}/{x}/{y}.svg',
          userAgentPackageName: 'com.suar.app',
          tileProvider: FMTCStore('tsunami_hazard_layer').getTileProvider(),
        ),
    ],
  );
}
```

---

## 3. Integrasi Tile Caching Luring di `map_cache_service.dart` (FMTC)

Untuk memastikan layer zona merah tsunami ikut tersimpan di SQLite HP ketika tombol **"Download Peta Evakuasi 3 KM"** ditekan oleh pengguna:

```dart
Future<void> downloadMapRadius(
  LatLng center, {
  double radiusInMeters = 3000,
}) async {
  try {
    const distance = Distance();
    final sw = distance.offset(center, radiusInMeters, 225);
    final ne = distance.offset(center, radiusInMeters, 45);

    final region = RectangleRegion(LatLngBounds(sw, ne));

    // 1. Unduh Base Map OSM
    final baseStore = FMTCStore('evacuation_map');
    await baseStore.manage.create();
    final downloadableBase = region.toDownloadable(
      minZoom: 14,
      maxZoom: 17,
      options: TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.suar.app',
      ),
    );
    await baseStore.download.startForeground(region: downloadableBase).downloadProgress.last;

    // 2. Unduh Overlay Zona Merah Tsunami Backend
    final tsunamiStore = FMTCStore('tsunami_hazard_layer');
    await tsunamiStore.manage.create();
    final downloadableTsunami = region.toDownloadable(
      minZoom: 14,
      maxZoom: 17,
      options: TileLayer(
        urlTemplate: 'https://your-suar-backend.com/alerts/tsunami-tile/{z}/{x}/{y}.svg',
        userAgentPackageName: 'com.suar.app',
      ),
    );
    await tsunamiStore.download.startForeground(region: downloadableTsunami).downloadProgress.last;

  } catch (e) {
    throw Exception('Gagal mengunduh peta evakuasi & tsunami hazard: $e');
  }
}
```

---

## 4. Panduan Offline Geofencing Fallback (Saat Internet Mati Total)

Ketika koneksi seluler dan internet mati total:
1. `flutter_map` akan otomatis mengambil gambar ubin peta dasar & ubin zona merah tsunami dari store SQLite `tsunami_hazard_layer` yang di-cache oleh FMTC.
2. Untuk pengecekan status alarm suara saat offline, simpan data grid bounding box ringan (`backend/data/tsunami/tsunami_jawa_bali_mobile.geojson`) di aset Flutter untuk pengecekan point-in-polygon lokal.

---

### 📞 Kontak & Dukungan Developer
Jika terdapat kendala atau pertanyaan saat pengintegrasian di Sisi Mobile, silakan hubungi tim Backend SUAR atau periksa status Swagger API di:
`http://{backend_host}:3000/api`
