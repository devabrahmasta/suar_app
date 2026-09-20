import 'package:latlong2/latlong.dart';

class Shelter {
  final String id;
  final String name;
  final String type;
  final LatLng position;

  Shelter({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
  });

  factory Shelter.fromJson(Map<String, dynamic> json) {
    final coordinates = json['location']['coordinates'] as List;
    return Shelter(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Titik Evakuasi',
      type: json['type'] as String? ?? 'TPS',
      position: LatLng(
        (coordinates[1] as num).toDouble(),
        (coordinates[0] as num).toDouble(),
      ),
    );
  }
}
