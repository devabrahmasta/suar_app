import 'package:flutter_test/flutter_test.dart';
import 'package:suar_app/features/map_evacuation/domain/shelter_model.dart';

void main() {
  group('Shelter.fromJson', () {
    test('reads GeoJSON coordinates as longitude then latitude', () {
      final shelter = Shelter.fromJson({
        'id': 'shelter-1',
        'name': 'Titik Evakuasi TPA (TPA-01)',
        'type': 'TPA',
        'location': {
          'type': 'Point',
          'coordinates': [110.29, -7.99],
        },
      });

      expect(shelter.id, 'shelter-1');
      expect(shelter.name, 'Titik Evakuasi TPA (TPA-01)');
      expect(shelter.type, 'TPA');
      expect(shelter.position.latitude, -7.99);
      expect(shelter.position.longitude, 110.29);
    });

    test('falls back to defaults for a missing name and type', () {
      final shelter = Shelter.fromJson({
        'id': 'shelter-2',
        'name': null,
        'type': null,
        'location': {
          'type': 'Point',
          'coordinates': [110.3, -7.8],
        },
      });

      expect(shelter.name, 'Titik Evakuasi');
      expect(shelter.type, 'TPS');
    });
  });
}
