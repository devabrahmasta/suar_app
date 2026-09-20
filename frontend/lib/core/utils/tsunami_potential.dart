bool isTsunamiPotential(String potensi) {
  final normalized = potensi.toLowerCase();
  return normalized.contains('tsunami') &&
      !normalized.contains('tidak berpotensi');
}
