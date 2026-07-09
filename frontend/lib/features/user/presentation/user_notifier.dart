import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../main.dart';
import '../domain/user_model.dart';
import '../data/user_local_service.dart';
import '../../../core/services/suar_backend_service.dart';

class UserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final String? userJson = prefs.getString('user_cache');

    if (userJson != null) {
      final user = UserModel.fromMap(jsonDecode(userJson));
      debugPrint('UserNotifier: Profil pengguna ditemukan di cache: ${user.fullName} (${user.deviceId})');
      
      // Sinkronisasi status perangkat ke backend secara asynchronous di background
      debugPrint('UserNotifier: Memulai sinkronisasi latar belakang ke cloud backend...');
      Future.microtask(() async {
        try {
          final backendService = ref.read(suarBackendServiceProvider);
          await backendService.registerDevice(
            deviceId: user.deviceId,
            fcmToken: 'mock_token_${user.deviceId.substring(0, 8)}',
            homeType: user.homeType,
            homeLatitude: user.homeLatitude,
            homeLongitude: user.homeLongitude,
          );
          debugPrint('UserNotifier: Sinkronisasi latar belakang ke backend berhasil.');
        } catch (e) {
          debugPrint('UserNotifier: Sinkronisasi latar belakang gagal (offline mode tetap berjalan): $e');
        }
      });
      
      return user;
    }
    debugPrint('UserNotifier: Tidak ada profil pengguna ter-cache.');
    return null;
  }

  Future<void> createUser({
    required String name,
    required String homeType,
    required double? homeLat,
    required double? homeLng,
  }) async {
    debugPrint('UserNotifier: Membuat profil pengguna baru: $name');
    final String generatedDeviceId = const Uuid().v4();
    final user = UserModel(
      fullName: name,
      deviceId: generatedDeviceId,
      homeType: homeType,
      homeLatitude: homeLat,
      homeLongitude: homeLng,
    );

    await UserLocalService.saveUser(user);
    state = user;

    // Registrasi perangkat baru ke cloud backend
    debugPrint('UserNotifier: Mendaftarkan perangkat baru $generatedDeviceId ke cloud backend...');
    try {
      final backendService = ref.read(suarBackendServiceProvider);
      await backendService.registerDevice(
        deviceId: generatedDeviceId,
        fcmToken: 'mock_token_${generatedDeviceId.substring(0, 8)}',
        homeType: homeType,
        homeLatitude: homeLat,
        homeLongitude: homeLng,
      );
      debugPrint('UserNotifier: Pendaftaran perangkat baru ke backend sukses.');
    } catch (e) {
      debugPrint('UserNotifier: Pendaftaran perangkat baru ke backend gagal (offline mode tetap berjalan): $e');
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserModel?>(() {
  return UserNotifier();
});
