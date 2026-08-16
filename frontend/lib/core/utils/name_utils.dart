/// Mengambil inisial dari nama lengkap (maks. 2 huruf), dipakai untuk
/// avatar bulat di header beranda & halaman profil.
String getInitials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.substring(0, 1).toUpperCase();
}
