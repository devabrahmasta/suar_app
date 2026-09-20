import 'package:flutter_test/flutter_test.dart';
import 'package:suar_app/core/utils/tsunami_potential.dart';

void main() {
  group('isTsunamiPotential', () {
    test('is true when BMKG reports a tsunami potential', () {
      expect(isTsunamiPotential('Berpotensi tsunami'), isTrue);
      expect(
        isTsunamiPotential(
          'Berpotensi TSUNAMI untuk diteruskan pada masyarakat',
        ),
        isTrue,
      );
    });

    test('is false when BMKG says there is no tsunami potential', () {
      expect(isTsunamiPotential('Tidak berpotensi tsunami'), isFalse);
      expect(isTsunamiPotential('TIDAK BERPOTENSI TSUNAMI'), isFalse);
    });

    test('is false when the text does not mention a tsunami', () {
      expect(isTsunamiPotential(''), isFalse);
      expect(isTsunamiPotential('-'), isFalse);
    });
  });
}
