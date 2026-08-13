import 'package:latlong2/latlong.dart';

enum ShelterType { tes, tea }

class ShelterModel {
  final String id;
  final String name;
  final ShelterType type; // tes: Tempat Evakuasi Sementara, tea: Tempat Evakuasi Akhir
  final LatLng location;
  final double elevationMeters;
  final int capacityTotal;
  final int capacityFilled;
  final bool hasWaterSupply; // Standar 15L/orang/hari
  final bool hasFoodLogistics; // Standar 2100 kalori/orang/hari
  final bool hasDisabilityAccess; // Ramah disabilitas (netra, tuli, fisik)
  final bool hasMedicalTeam;
  final String address;
  final String contactPerson;

  ShelterModel({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.elevationMeters,
    required this.capacityTotal,
    required this.capacityFilled,
    required this.hasWaterSupply,
    required this.hasFoodLogistics,
    required this.hasDisabilityAccess,
    required this.hasMedicalTeam,
    required this.address,
    required this.contactPerson,
  });
}

class ShelterDataService {
  /// Mendapatkan daftar titik kumpul resmi BNPB/BMKG berdasarkan koordinat pengguna
  static List<ShelterModel> getNearbyShelters(LatLng userLocation) {
    // Memberikan titik TES dan TEA di sekitar posisi pengguna
    final double lat = userLocation.latitude;
    final double lng = userLocation.longitude;

    return [
      ShelterModel(
        id: 'TES-01',
        name: 'TES Balai Desa / Gedung Serbaguna',
        type: ShelterType.tes,
        location: LatLng(lat + 0.005, lng + 0.004),
        elevationMeters: 28.5,
        capacityTotal: 350,
        capacityFilled: 120,
        hasWaterSupply: true,
        hasFoodLogistics: true,
        hasDisabilityAccess: true,
        hasMedicalTeam: true,
        address: 'Jl. Raya Evakuasi No. 12 (Jarak 450m)',
        contactPerson: 'Posko BPBD (0812-3456-7890)',
      ),
      ShelterModel(
        id: 'TES-02',
        name: 'TES Bukit Ketinggian & Lapangan Terbuka',
        type: ShelterType.tes,
        location: LatLng(lat + 0.008, lng - 0.003),
        elevationMeters: 45.0,
        capacityTotal: 600,
        capacityFilled: 180,
        hasWaterSupply: true,
        hasFoodLogistics: false,
        hasDisabilityAccess: false,
        hasMedicalTeam: false,
        address: 'Bukit Siaga Zona 1 (Jarak 850m)',
        contactPerson: 'Relawan Karang Taruna',
      ),
      ShelterModel(
        id: 'TEA-01',
        name: 'TEA Posko Induk Pengungsian BNPB',
        type: ShelterType.tea,
        location: LatLng(lat + 0.015, lng + 0.012),
        elevationMeters: 62.0,
        capacityTotal: 1500,
        capacityFilled: 420,
        hasWaterSupply: true,
        hasFoodLogistics: true,
        hasDisabilityAccess: true,
        hasMedicalTeam: true,
        address: 'Kompleks Stadion & Gelanggang Olahraga Utama',
        contactPerson: 'Komandan Posko TNI/BNPB (112)',
      ),
    ];
  }
}
