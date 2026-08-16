/// Menentukan headline alert dari field `potensi` (mis. dari BMKG).
///
/// Field ini biasanya singkat ("Tidak berpotensi tsunami"), tapi headline
/// UI cuma punya ruang terbatas — kalau suatu saat sumber data (API BMKG,
/// backend, atau data uji) ngirim teks yang kepanjangan, jangan asal
/// ditampilkan mentah-mentah sebagai judul besar (bisa merusak layout).
/// Sebagai gantinya, jatuh balik ke teks pendek standar.
String resolveAlertHeadline(
  String potensi, {
  required String fallback,
  int maxLength = 40,
}) {
  final trimmed = potensi.trim();
  if (trimmed.isEmpty || trimmed.length > maxLength) {
    return fallback;
  }
  return trimmed.toUpperCase();
}
