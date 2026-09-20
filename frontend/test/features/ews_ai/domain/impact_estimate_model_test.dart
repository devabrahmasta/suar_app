import 'package:flutter_test/flutter_test.dart';
import 'package:suar_app/features/ews_ai/domain/gempa_model.dart';
import 'package:suar_app/features/ews_ai/domain/impact_estimate_model.dart';

void main() {
  group('ImpactEstimate.shakingLabel', () {
    String labelFor(String level) =>
        ImpactEstimate(estimatedMmi: 5, shakingLevel: level).shakingLabel;

    test('translates every backend shaking level', () {
      expect(labelFor('VERY_SEVERE'), 'Sangat kuat');
      expect(labelFor('MODERATE'), 'Sedang');
      expect(labelFor('LIGHT'), 'Ringan');
      expect(labelFor('MINOR'), 'Lemah');
    });
  });

  group('GempaModel.fromBackendJson', () {
    test('keeps the backend alert id for impact lookups', () {
      final gempa = GempaModel.fromBackendJson({
        'id': 'alert-1',
        'alertTime': '2026-09-20T01:00:00.000Z',
        'magnitude': 6.1,
        'depth': '10 km',
        'wilayah': 'Bantul',
        'potensi': 'Tidak berpotensi tsunami',
        'epicenter': {
          'coordinates': [110.29, -7.99],
        },
      });

      expect(gempa.alertId, 'alert-1');
    });
  });
}
