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
  final _hpController = TextEditingController();

  static const int _totalSlides = 5;
  int _currentIndex = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _namaController.dispose();
    _hpController.dispose();
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
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  // ── Slide 2: Location Permission ───────────────────────────────────────────
  Future<void> _handleLocationSlide() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final bool granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (!granted) {
        _showDangerSnackBar('Izin lokasi wajib diberikan untuk evakuasi.');
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

      if (status.isDenied || status.isPermanentlyDenied) {
        _showDangerSnackBar(
          'Izin optimasi baterai diperlukan agar SUAR tetap aktif.',
        );
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
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.nearbyWifiDevices,
      ].request();

      final allGranted = statuses.values.every(
        (s) => s.isGranted || s.isLimited,
      );

      if (!allGranted) {
        _showDangerSnackBar(
          'Izin perangkat sekitar wajib untuk fitur Mesh Offline.',
        );
        return;
      }

      _nextPage();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Slide 5: Submit Identity ───────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(userProvider.notifier).createUser(
            _namaController.text.trim(),
            _hpController.text.trim(),
            '',
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
              tween: Tween(
                begin: 0,
                end: (_currentIndex + 1) / _totalSlides,
              ),
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
                    hpController: _hpController,
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
    required this.hpController,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController namaController;
  final TextEditingController hpController;
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
            Text('Siapa kamu di jaringan SUAR?', style: theme.textTheme.bodyMedium),
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
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama lengkap tidak boleh kosong.' : null,
              decoration: const InputDecoration(
                hintText: 'cth. Budi Santoso',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),

            const SizedBox(height: 20),

            // NOMOR HP
            Text(
              'NOMOR HP',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: hpController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nomor HP tidak boleh kosong.' : null,
              decoration: const InputDecoration(
                hintText: 'cth. 08123456789',
                prefixIcon: Icon(Icons.phone_outlined),
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
