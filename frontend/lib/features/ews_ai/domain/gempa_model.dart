class GempaModel {
  final String tanggal;
  final String jam;
  final String dateTime;
  final String coordinates;
  final String magnitude;
  final String kedalaman;
  final String wilayah;
  final String potensi;
  final String dirasakan;
  final String shakemapUrl;

  GempaModel({
    required this.tanggal,
    required this.jam,
    required this.dateTime,
    required this.coordinates,
    required this.magnitude,
    required this.kedalaman,
    required this.wilayah,
    required this.potensi,
    required this.dirasakan,
    required this.shakemapUrl,
  });

  factory GempaModel.fromJson(Map<String, dynamic> json) {
    final gempa = json['Infogempa']['gempa'];

    return GempaModel(
      tanggal: gempa['Tanggal'] ?? '',
      jam: gempa['Jam'] ?? '',
      dateTime: gempa['DateTime'] ?? '',
      coordinates: gempa['Coordinates'] ?? '',
      magnitude: gempa['Magnitude'] ?? '',
      kedalaman: gempa['Kedalaman'] ?? '',
      wilayah: gempa['Wilayah'] ?? '',
      potensi: gempa['Potensi'] ?? '',
      dirasakan: gempa['Dirasakan'] ?? 'Tidak ada data',
      shakemapUrl: gempa['Shakemap'] != null
          ? 'https://static.bmkg.go.id/${gempa['Shakemap']}'
          : '',
    );
  }

  factory GempaModel.fromBackendJson(Map<String, dynamic> json) {
    final alertTimeStr = json['alertTime'] ?? '';
    DateTime? alertDateTime;
    try {
      alertDateTime = DateTime.tryParse(alertTimeStr);
    } catch (_) {}

    String tanggal = '';
    String jam = '';
    if (alertDateTime != null) {
      tanggal = "${alertDateTime.day}-${alertDateTime.month}-${alertDateTime.year}";
      jam = "${alertDateTime.hour}:${alertDateTime.minute}:${alertDateTime.second} WIB";
    }

    final epicenter = json['epicenter'] as Map<String, dynamic>?;
    final coords = epicenter?['coordinates'] as List<dynamic>?;
    String coordinatesStr = '0.0,0.0';
    if (coords != null && coords.length >= 2) {
      final double lng = (coords[0] as num).toDouble();
      final double lat = (coords[1] as num).toDouble();
      coordinatesStr = '$lat,$lng';
    }

    return GempaModel(
      tanggal: tanggal,
      jam: jam,
      dateTime: alertTimeStr,
      coordinates: coordinatesStr,
      magnitude: (json['magnitude'] ?? 0.0).toString(),
      kedalaman: json['depth'] ?? '',
      wilayah: json['wilayah'] ?? '',
      potensi: json['potensi'] ?? '',
      dirasakan: 'Tidak ada data',
      shakemapUrl: '',
    );
  }
}
