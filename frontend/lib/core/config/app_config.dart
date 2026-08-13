class AppConfig {
  /// Toggle untuk menggunakan Mock Data vs Cloud Backend asli.
  /// Set `true` saat demo proposal / offline mode tanpa backend.
  /// Set `false` saat backend NestJS cloud sudah siap.
  static const bool useMockBackend = true;

  /// Memicu notifikasi lokal otomatis saat simulasi peringatan dini aktif.
  static const bool enableLocalMockNotification = true;
}
