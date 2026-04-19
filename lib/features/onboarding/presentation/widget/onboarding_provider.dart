import 'package:flutter/material.dart';

class OnboardingProvider extends ChangeNotifier {
  int _currentIndex = 0;
  bool _hasCompleted = false;

  int get currentIndex => _currentIndex;
  bool get hasCompleted => _hasCompleted;

  // Fungsi yang dipanggil saat user geser slide
  void updateIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  // Fungsi yang dipanggil saat user selesai isi Form di slide terakhir
  Future<void> completeOnboarding() async {
    _hasCompleted = true;
    
    // ⚠️ TODO: Simpan status ini ke Local Storage (SharedPreferences)
    
    notifyListeners();
  }
}