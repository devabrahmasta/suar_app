import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:suar_app/core/theme/app_colors.dart';
import 'package:suar_app/features/onboarding/presentation/widget/onboarding_slide.dart';
import 'package:suar_app/features/user/presentation/user_notifier.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();

  static const int _totalSlides = 5;
  int _currentIndex = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _showDangerSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.warning),
    );
  }

  // Returns true  → user chose the positive action (retry / open settings)
  // Returns false → user chose skip
  Future<bool> _showRationaleDialog({
    required String title,
    required String body,
    required bool isPermanent,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Icon(
              isPermanent
                  ? Icons.settings_outlined
                  : Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          body,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Lewati',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isPermanent ? 'Buka Pengaturan' : 'Coba Lagi'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Slide 2: Location Permission ───────────────────────────────────────────
  Future<void> _handleLocationSlide() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Still denied after first request → show rationale dialog
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final retry = await _showRationaleDialog(
          title: 'Izin Lokasi Diperlukan',
          body:
              'SUAR membutuhkan GPS untuk menampilkan rute evakuasi ke titik '
              'aman terdekat. Tanpa izin ini, navigasi darurat tidak bisa berfungsi.',
          isPermanent: false,
        );
        if (!mounted) return;
        if (retry) {
          // Recurse to try again
          return _handleLocationSlide();
        } else {
          _showDangerSnackBar('Izin lokasi wajib diberikan untuk evakuasi.');
          return;
        }
      }

      // Permanently denied → direct user to app settings
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final openSettings = await _showRationaleDialog(
          title: 'Izin Lokasi Diperlukan',
          body:
              'SUAR membutuhkan GPS untuk menampilkan rute evakuasi ke titik aman. '
              'Anda telah menolak izin ini sebelumnya. Silakan buka '
              'Pengaturan > Aplikasi > SUAR > Izin untuk mengaktifkannya secara manual.',
          isPermanent: true,
        );
        if (!mounted) return;
        if (openSettings) {
          await openAppSettings();
          // Re-check after returning from settings
          final recheck = await Geolocator.checkPermission();
          if (recheck == LocationPermission.whileInUse ||
              recheck == LocationPermission.always) {
            _nextPage();
          } else {
            _showDangerSnackBar('Izin lokasi wajib diberikan untuk evakuasi.');
          }
        } else {
          _showDangerSnackBar('Izin lokasi wajib diberikan untuk evakuasi.');
        }
        return;
      }

      _nextPage();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Slide 3: Battery Optimization ─────────────────────────────────────────
  Future<void> _handleBatterySlide() async {
    setState(() => _isLoading = true);
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();

      if (status.isDenied) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final retry = await _showRationaleDialog(
          title: 'Optimasi Baterai',
          body:
              'SUAR perlu berjalan di latar belakang agar tetap aktif saat '
              'terjadi bencana. Tanpa ini, notifikasi darurat mungkin tertunda.',
          isPermanent: false,
        );
        if (!mounted) return;
        if (retry) {
          return _handleBatterySlide();
        } else {
          // Battery is skippable — warn but allow to proceed
          _showWarningSnackBar('Fitur background mungkin tidak optimal.');
          _nextPage();
        }
        return;
      }

      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final openSettings = await _showRationaleDialog(
          title: 'Optimasi Baterai',
          body:
              'Anda telah menolak izin ini sebelumnya. Silakan buka '
              'Pengaturan > Aplikasi > SUAR > Baterai untuk mengaktifkannya secara manual.',
          isPermanent: true,
        );
        if (!mounted) return;
        if (openSettings) {
          await openAppSettings();
          final recheck = await Permission.ignoreBatteryOptimizations.status;
          if (recheck.isGranted) {
            _nextPage();
          } else {
            _showWarningSnackBar('Fitur background mungkin tidak optimal.');
            _nextPage();
          }
        } else {
          // Still skippable
          _showWarningSnackBar('Fitur background mungkin tidak optimal.');
          _nextPage();
        }
        return;
      }

      _nextPage();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Slide 4: Bluetooth & Nearby Wifi ──────────────────────────────────────
  Future<void> _handleMeshSlide() async {
    setState(() => _isLoading = true);
    try {
      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.nearbyWifiDevices,
      ];

      final statuses = await permissions.request();

      final isModernGranted = statuses[Permission.bluetoothScan]!.isGranted &&
          statuses[Permission.bluetoothConnect]!.isGranted &&
          statuses[Permission.nearbyWifiDevices]!.isGranted;

      final isLegacyGranted = statuses[Permission.bluetooth]!.isGranted;

      if (isModernGranted || isLegacyGranted) {
        _nextPage();
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      bool anyPermanent = statuses[Permission.bluetoothScan]!.isPermanentlyDenied ||
          statuses[Permission.bluetoothConnect]!.isPermanentlyDenied ||
          statuses[Permission.nearbyWifiDevices]!.isPermanentlyDenied;
          
      if (!anyPermanent && !isModernGranted) {
        anyPermanent = statuses[Permission.bluetooth]!.isPermanentlyDenied;
      }

      if (anyPermanent) {
        final openSettings = await _showRationaleDialog(
          title: 'Izin Perangkat Sekitar Diperlukan',
          body:
              'SUAR membutuhkan Bluetooth dan Wi-Fi terdekat untuk komunikasi '
              'mesh peer-to-peer saat jaringan putus. Anda telah menolak izin ini '
              'sebelumnya. Silakan buka Pengaturan > Aplikasi > SUAR > Izin untuk '
              'mengaktifkannya secara manual.',
          isPermanent: true,
        );
        if (!mounted) return;
        if (openSettings) {
          await openAppSettings();
          final modernOk = await Permission.bluetoothScan.isGranted &&
              await Permission.bluetoothConnect.isGranted &&
              await Permission.nearbyWifiDevices.isGranted;
          final legacyOk = await Permission.bluetooth.isGranted;

          if (modernOk || legacyOk) {
            _nextPage();
          } else {
            _showDangerSnackBar(
              'Izin perangkat sekitar wajib untuk fitur Mesh Offline.',
            );
          }
        } else {
          _showDangerSnackBar(
            'Izin perangkat sekitar wajib untuk fitur Mesh Offline.',
          );
        }
      } else {
        final retry = await _showRationaleDialog(
          title: 'Izin Perangkat Sekitar Diperlukan',
          body:
              'SUAR membutuhkan Bluetooth dan Wi-Fi terdekat untuk komunikasi '
              'mesh peer-to-peer agar Anda tetap terhubung dengan relawan saat '
              'internet tidak tersedia.',
          isPermanent: false,
        );
        if (!mounted) return;
        if (retry) {
          return _handleMeshSlide();
        } else {
          _showDangerSnackBar(
            'Izin perangkat sekitar wajib untuk fitur Mesh Offline.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Slide 5: Submit Identity ───────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(userProvider.notifier)
          .createUser(
            _namaController.text.trim(),
          );
      // go_router redirect handles routing after state updates.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress indicator ──────────────────────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (_currentIndex + 1) / _totalSlides),
              duration: const Duration(milliseconds: 350),
              builder: (context, value, child) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),

            // ── Slides ─────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentIndex = i),
                children: [
                  // Slide 1 — Sistem Peringatan
                  OnboardingSlide(
                    image: 'assets/images/slide_1.png',
                    title: 'Sistem Peringatan',
                    desc:
                        'SUAR tetap menyala saat segalanya padam. Terhubung dengan relawan dan tim darurat tanpa butuh internet.',
                    buttonText: 'Lanjut',
                    isLoading: false,
                    onButtonPressed: _nextPage,
                  ),

                  // Slide 2 — Akses Peta Evakuasi
                  OnboardingSlide(
                    image: 'assets/images/slide_2.png',
                    title: 'Akses Peta Evakuasi',
                    desc:
                        'Peta jalur evakuasi tersimpan offline. SUAR butuh GPS Anda untuk menunjukkan rute darurat terdekat ke titik aman.',
                    buttonText: 'Lanjut',
                    isLoading: _isLoading && _currentIndex == 1,
                    onButtonPressed: _handleLocationSlide,
                  ),

                  // Slide 3 — Optimasi Baterai
                  OnboardingSlide(
                    image: 'assets/images/slide_3.png',
                    title: 'Optimasi Baterai',
                    desc:
                        'Agar SUAR tetap aktif di latar belakang saat situasi darurat, izinkan aplikasi berjalan bebas dari pembatas baterai.',
                    buttonText: 'Lanjut',
                    isLoading: _isLoading && _currentIndex == 2,
                    onButtonPressed: _handleBatterySlide,
                  ),

                  // Slide 4 — Jaringan Offline & Bluetooth Mesh
                  OnboardingSlide(
                    image: 'assets/images/slide_4.png',
                    title: 'Jaringan Offline & Bluetooth Mesh',
                    desc:
                        'Berkomunikasi langsung dengan relawan terdekat tanpa internet menggunakan teknologi peer-to-peer terenkripsi.',
                    buttonText: 'Lanjut',
                    isLoading: _isLoading && _currentIndex == 3,
                    onButtonPressed: _handleMeshSlide,
                  ),

                  // Slide 5 — Identitas Radar (Form)
                  _IdentityFormSlide(
                    formKey: _formKey,
                    namaController: _namaController,
                    isLoading: _isLoading && _currentIndex == 4,
                    onSubmit: _handleSubmit,
                  ),
                ],
              ),
            ),

            // ── Dot indicators ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalSlides,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentIndex == i ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 5 — Identity Form
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityFormSlide extends StatelessWidget {
  const _IdentityFormSlide({
    required this.formKey,
    required this.namaController,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController namaController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identitas Radar', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Siapa kamu di jaringan SUAR?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Warning box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gunakan data asli. Anda hanya dikenali dari identitas ini saat jaringan offline.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // NAMA LENGKAP
            Text(
              'NAMA LENGKAP',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: namaController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama lengkap tidak boleh kosong.'
                  : null,
              decoration: const InputDecoration(
                hintText: 'cth. Budi Santoso',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.white,
                        ),
                      )
                    : const Text(
                        'Masuk Aplikasi',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
